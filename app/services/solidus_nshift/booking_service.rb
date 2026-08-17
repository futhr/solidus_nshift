# frozen_string_literal: true

module SolidusNshift
  class BookingService
    UNKNOWN_ERRORS = [TimeoutUnknownOutcome, MalformedResponseError].freeze

    def initialize(shipment:)
      @shipment = shipment
    end

    def call
      @fulfillment = FulfillmentIntent.new(shipment: @shipment).call
      return @fulfillment if @fulfillment.booked?

      if @fulfillment.connection.checkout_enabled? && @fulfillment.checkout_partial_shipment_id.blank?
        process_checkout
        return @fulfillment if @fulfillment.checkout_partial_shipment_id.blank?
      end
      return @fulfillment if @fulfillment.state == "reconciliation_pending"

      if @fulfillment.connection.delivery_enabled?
        process_delivery unless @fulfillment.provider_shipment_id.present?
      else
        @fulfillment.update!({state: "partial_created"}.merge(@fulfillment.clear_error_attributes))
      end
      @fulfillment
    end

    private

    def process_checkout
      dispatched = false
      payload = Checkout::PartialShipmentPayload.new(fulfillment: @fulfillment).call
      client = @fulfillment.connection.checkout_client
      operation = operation_for("checkout_partial", payload)
      return unless claim(operation)

      response = instrument("checkout", "partial_shipment") do
        dispatched = true
        client.create_partial_shipment(payload:)
      end
      resource_id = response["id"]
      raise MalformedResponseError, "nShift Checkout partial shipment omitted id" if resource_id.to_s.empty?

      Fulfillment.transaction do
        operation.mark_succeeded!(provider_resource_id: resource_id.to_s)
        @fulfillment.update!(
          {state: "partial_created", checkout_partial_shipment_id: resource_id.to_s}.merge(@fulfillment.clear_error_attributes)
        )
      end
    rescue *UNKNOWN_ERRORS => error
      unless dispatched
        mark_rejected(operation, error) if operation
        raise
      end

      mark_unknown(operation, error)
    rescue Error => error
      mark_rejected(operation, error)
    rescue => error
      unless dispatched
        mark_rejected(operation, error) if operation
        raise
      end

      mark_unknown(operation, error)
      raise
    end

    def process_delivery
      dispatched = false
      payload = Delivery::ShipmentPayload.new(fulfillment: @fulfillment).call
      client = @fulfillment.connection.delivery_client
      operation = operation_for("delivery_booking", payload)
      return unless claim(operation)

      shipment = instrument("delivery", "create_shipment") do
        dispatched = true
        client.create_shipment(payload:)
      end
      PersistDeliveryResult.new(fulfillment: @fulfillment, shipment:, operation:).call
    rescue *UNKNOWN_ERRORS => error
      unless dispatched
        mark_rejected(operation, error) if operation
        raise
      end

      mark_unknown(operation, error, reconcile: true)
    rescue Error => error
      mark_rejected(operation, error)
    rescue => error
      unless dispatched
        mark_rejected(operation, error) if operation
        raise
      end

      mark_unknown(operation, error, reconcile: true)
      raise
    end

    def operation_for(kind, payload)
      fingerprint = PayloadFingerprint.call(payload)
      OperationIntent.new(fulfillment: @fulfillment, kind:, fingerprint:).call
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
      JobEnqueuer.call(
        job_class: SolidusNshift::ReconcileBookingJob,
        arguments: [@fulfillment.id],
        operation: "reconcile_booking",
        metadata: {fulfillment_id: @fulfillment.id, connection_id: @fulfillment.connection_id}
      )
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
