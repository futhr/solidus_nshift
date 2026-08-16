# frozen_string_literal: true

module SolidusNshift
  class BookingService
    UNKNOWN_ERRORS = [TimeoutUnknownOutcome, MalformedResponseError].freeze

    def initialize(shipment:)
      @shipment = shipment
    end

    def call
      selection = SelectionValidator.new(shipment: @shipment).call
      @fulfillment = find_or_create_fulfillment(selection)
      return @fulfillment if @fulfillment.booked?

      process_checkout if @fulfillment.connection.checkout_enabled? && @fulfillment.checkout_partial_shipment_id.blank?
      return @fulfillment if %w[reconciliation_pending rejected].include?(@fulfillment.state)

      if @fulfillment.connection.delivery_enabled?
        process_delivery unless @fulfillment.provider_shipment_id.present?
      else
        @fulfillment.update!({state: "partial_created"}.merge(@fulfillment.clear_error_attributes))
      end
      @fulfillment
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    private

    def find_or_create_fulfillment(selection)
      Fulfillment.find_or_create_by!(shipment: @shipment) do |record|
        record.connection = selection.connection
        record.rate_selection = selection
        record.merchant_reference = Reference.for(@shipment)
      end.tap do |record|
        if record.rate_selection_id != selection.id || record.connection_id != selection.connection_id
          raise ShipmentConflictError, "shipment already has a different nShift fulfillment intent"
        end
      end
    end

    def process_checkout
      payload = Checkout::PartialShipmentPayload.new(fulfillment: @fulfillment).call
      operation = operation_for("checkout_partial", payload)
      return unless claim(operation)

      response = instrument("checkout", "partial_shipment") do
        @fulfillment.connection.checkout_client.create_partial_shipment(payload:)
      end
      resource_id = response["id"] || response["shipmentId"] || response.dig("shipment", "id")
      raise MalformedResponseError, "nShift Checkout partial shipment omitted id" if resource_id.to_s.empty?

      Fulfillment.transaction do
        operation.mark_succeeded!(provider_resource_id: resource_id.to_s)
        @fulfillment.update!(
          {state: "partial_created", checkout_partial_shipment_id: resource_id.to_s}.merge(@fulfillment.clear_error_attributes)
        )
      end
    rescue *UNKNOWN_ERRORS => error
      mark_unknown(operation, error)
    rescue Error => error
      mark_rejected(operation, error)
    rescue => error
      mark_unknown(operation, error)
      raise
    end

    def process_delivery
      payload = Delivery::ShipmentPayload.new(fulfillment: @fulfillment).call
      operation = operation_for("delivery_booking", payload)
      return unless claim(operation)

      shipment = instrument("delivery", "create_shipment") do
        @fulfillment.connection.delivery_client.create_shipment(payload:)
      end
      PersistDeliveryResult.new(fulfillment: @fulfillment, shipment:, operation:).call
    rescue *UNKNOWN_ERRORS => error
      mark_unknown(operation, error, reconcile: true)
    rescue Error => error
      mark_rejected(operation, error)
    rescue => error
      mark_unknown(operation, error, reconcile: true)
      raise
    end

    def operation_for(kind, payload)
      fingerprint = PayloadFingerprint.call(payload)
      operation = @fulfillment.operations.find_or_create_by!(kind:) do |record|
        record.request_fingerprint = fingerprint
      end
      if operation.request_fingerprint != fingerprint
        raise ShipmentConflictError, "nShift booking payload changed after intent was persisted"
      end

      operation
    end

    def claim(operation)
      claimed = operation.claim!
      @fulfillment.update!(state: "booking") if claimed
      claimed
    rescue ReconciliationRequired => error
      @fulfillment.record_error!(error, state: "reconciliation_pending")
      enqueue_reconciliation if operation.kind == "delivery_booking"
      false
    end

    def mark_unknown(operation, error, reconcile: false)
      operation&.mark_unknown!(error)
      @fulfillment&.record_error!(error, state: "reconciliation_pending")
      enqueue_reconciliation if reconcile && @fulfillment&.persisted?
    end

    def mark_rejected(operation, error)
      operation&.mark_rejected!(error)
      @fulfillment&.record_error!(error, state: "rejected")
    end

    def enqueue_reconciliation
      SolidusNshift::ReconcileBookingJob.perform_later(@fulfillment.id)
    end

    def instrument(api_family, operation, &)
      ActiveSupport::Notifications.instrument(
        "solidus_nshift.request",
        api_family:,
        operation:,
        fulfillment_id: @fulfillment.id,
        connection_id: @fulfillment.connection_id,
        &
      )
    end
  end
end
