# frozen_string_literal: true

module SolidusNshift
  class CancelFulfillment
    def initialize(fulfillment:)
      @fulfillment = fulfillment
    end

    def call
      raise ValidationError, "nShift shipment has not been booked" if @fulfillment.provider_shipment_id.blank?
      return @fulfillment if @fulfillment.state == "canceled"

      operation = @fulfillment.operations.find_or_create_by!(kind: "delivery_cancel") do |record|
        record.request_fingerprint = PayloadFingerprint.call({
          shipment_id: @fulfillment.provider_shipment_id,
          merchant_reference: @fulfillment.merchant_reference
        })
      end
      return @fulfillment unless operation.claim!

      @fulfillment.connection.delivery_client.cancel_shipment(shipment_id: @fulfillment.provider_shipment_id)
      Fulfillment.transaction do
        operation.mark_succeeded!(provider_resource_id: @fulfillment.provider_shipment_id)
        @fulfillment.update!(
          {state: "canceled", provider_status: "CANCELED"}.merge(@fulfillment.clear_error_attributes)
        )
      end
      @fulfillment
    rescue TimeoutUnknownOutcome, MalformedResponseError => error
      operation&.mark_unknown!(error)
      @fulfillment.record_error!(error, state: "reconciliation_pending")
      @fulfillment
    rescue ReconciliationRequired => error
      @fulfillment.record_error!(error, state: "reconciliation_pending")
      @fulfillment
    rescue Error => error
      operation&.mark_rejected!(error)
      @fulfillment.record_error!(error)
      @fulfillment
    rescue => error
      operation&.mark_unknown!(error)
      @fulfillment.record_error!(error, state: "reconciliation_pending")
      raise
    end
  end
end
