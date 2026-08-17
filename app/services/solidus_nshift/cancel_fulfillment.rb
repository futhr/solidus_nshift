# frozen_string_literal: true

module SolidusNshift
  class CancelFulfillment
    def initialize(fulfillment:)
      @fulfillment = fulfillment
    end

    def call
      dispatched = false
      raise ValidationError, "nShift shipment has not been booked" if @fulfillment.provider_shipment_id.blank?
      return @fulfillment if @fulfillment.state == "canceled"

      client = @fulfillment.connection.delivery_client
      fingerprint = PayloadFingerprint.call({
        shipment_id: @fulfillment.provider_shipment_id,
        merchant_reference: @fulfillment.merchant_reference
      })
      operation = OperationIntent.new(
        fulfillment: @fulfillment, kind: "delivery_cancel", fingerprint:
      ).call
      return @fulfillment unless operation.claim!

      dispatched = true
      client.cancel_shipment(shipment_id: @fulfillment.provider_shipment_id)
      Fulfillment.transaction do
        operation.mark_succeeded!(provider_resource_id: @fulfillment.provider_shipment_id)
        @fulfillment.update!(
          {state: "canceled", provider_status: "CANCELED"}.merge(@fulfillment.clear_error_attributes)
        )
      end
      @fulfillment
    rescue TimeoutUnknownOutcome, MalformedResponseError => error
      unless dispatched
        operation&.mark_rejected!(error)
        raise
      end

      operation&.mark_unknown!(error)
      @fulfillment.record_error!(error, state: "reconciliation_pending")
      enqueue_reconciliation
      @fulfillment
    rescue ReconciliationRequired => error
      @fulfillment.record_error!(error, state: "reconciliation_pending")
      enqueue_reconciliation
      @fulfillment
    rescue Error => error
      operation&.mark_rejected!(error)
      @fulfillment.record_error!(error)
      @fulfillment
    rescue => error
      unless dispatched
        operation&.mark_rejected!(error)
        raise
      end

      operation&.mark_unknown!(error)
      @fulfillment.record_error!(error, state: "reconciliation_pending")
      enqueue_reconciliation
      raise
    end

    private

    def enqueue_reconciliation
      JobEnqueuer.call(
        job_class: ReconcileBookingJob,
        arguments: [@fulfillment.id],
        operation: "reconcile_cancellation",
        metadata: {fulfillment_id: @fulfillment.id, connection_id: @fulfillment.connection_id}
      )
    end
  end
end
