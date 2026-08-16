# frozen_string_literal: true

module SolidusNshift
  class ReconcileBooking
    def initialize(fulfillment:)
      @fulfillment = fulfillment
    end

    def call
      return @fulfillment if @fulfillment.booked?
      return unresolved_checkout unless checkout_resolved?
      return reconcile_cancel if cancel_unresolved?

      operation = @fulfillment.operations.find_by(kind: "delivery_booking")
      return @fulfillment unless operation && %w[in_progress unknown].include?(operation.status)

      shipment = @fulfillment.connection.delivery_client.find_shipment(reference: @fulfillment.merchant_reference)
      if shipment
        PersistDeliveryResult.new(fulfillment: @fulfillment, shipment:, operation:).call
      else
        @fulfillment.update!(last_reconciled_at: Time.current, state: "reconciliation_pending")
      end
      @fulfillment
    rescue Error => error
      @fulfillment.record_error!(error, state: "reconciliation_pending")
      raise
    end

    private

    def checkout_resolved?
      operation = @fulfillment.operations.find_by(kind: "checkout_partial")
      !operation || operation.status == "succeeded"
    end

    def unresolved_checkout
      error = ReconciliationRequired.new(
        "nShift Checkout does not expose a safe partial-shipment lookup; manual provider verification is required"
      )
      @fulfillment.record_error!(error, state: "reconciliation_pending")
      @fulfillment.update!(last_reconciled_at: Time.current)
      @fulfillment
    end

    def cancel_unresolved?
      operation = @fulfillment.operations.find_by(kind: "delivery_cancel")
      operation && %w[in_progress unknown].include?(operation.status)
    end

    def reconcile_cancel
      operation = @fulfillment.operations.find_by!(kind: "delivery_cancel")
      shipment = @fulfillment.connection.delivery_client.find_shipment(reference: @fulfillment.merchant_reference)
      if shipment && shipment.status.to_s.casecmp?("canceled")
        Fulfillment.transaction do
          operation.mark_succeeded!(provider_resource_id: @fulfillment.provider_shipment_id)
          @fulfillment.update!(
            {state: "canceled", provider_status: shipment.status}.merge(@fulfillment.clear_error_attributes)
          )
        end
      else
        @fulfillment.update!(last_reconciled_at: Time.current, state: "reconciliation_pending")
      end
      @fulfillment
    end
  end
end
