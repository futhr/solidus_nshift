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
        persist_documents(@shipment.documents)
        @fulfillment.shipment.update_column(:tracking, @shipment.tracking_number) if @shipment.tracking_number.present?
      end
      enqueue_tracking
      @fulfillment
    end

    private

    def persist_documents(documents)
      documents.each do |provider_document|
        document = @fulfillment.documents.find_or_initialize_by(provider_document_id: provider_document.id)
        document.assign_attributes(
          description: provider_document.description,
          format: provider_document.format,
          content_type: provider_document.content_type
        )
        document.save!
      end
    end

    def enqueue_tracking
      return unless @fulfillment.connection.tracking_enabled?

      SolidusNshift.configuration.sync_tracking_job.call.perform_later(@fulfillment.id)
    end
  end
end
