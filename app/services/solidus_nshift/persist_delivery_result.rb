# frozen_string_literal: true

module SolidusNshift
  class PersistDeliveryResult
    def initialize(fulfillment:, shipment:, operation: nil)
      @fulfillment = fulfillment
      @shipment = shipment
      @operation = operation
    end

    def call
      Fulfillment.transaction do
        @operation&.mark_succeeded!(provider_resource_id: @shipment.id)
        @fulfillment.update!(
          {
            state: "booked",
            provider_shipment_id: @shipment.id,
            provider_status: @shipment.status,
            tracking_number: @shipment.tracking_number
          }.merge(@fulfillment.clear_error_attributes)
        )
        PersistDocuments.new(fulfillment: @fulfillment, documents: @shipment.documents).call
        @fulfillment.shipment.update!(tracking: @shipment.tracking_number) if @shipment.tracking_number.present?
      end
      enqueue_tracking_safely
      @fulfillment
    end

    private

    def enqueue_tracking_safely
      return unless @fulfillment.connection.tracking_enabled?

      JobEnqueuer.call(
        job_class: SolidusNshift.configuration.sync_tracking_job.call,
        arguments: [@fulfillment.id],
        operation: "enqueue_tracking",
        metadata: {fulfillment_id: @fulfillment.id, connection_id: @fulfillment.connection_id}
      )
    end
  end
end
