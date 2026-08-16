# frozen_string_literal: true

module SolidusNshift
  class RefreshDocuments
    def initialize(fulfillment:)
      @fulfillment = fulfillment
    end

    def call
      raise ValidationError, "nShift shipment has not been booked" if @fulfillment.provider_shipment_id.blank?

      values = @fulfillment.connection.delivery_client.list_documents(shipment_id: @fulfillment.provider_shipment_id)
      Fulfillment.transaction do
        values.each do |provider_document|
          document = @fulfillment.documents.find_or_initialize_by(provider_document_id: provider_document.id)
          document.update!(
            description: provider_document.description,
            format: provider_document.format,
            content_type: provider_document.content_type
          )
        end
      end
      @fulfillment.documents.reload
    end
  end
end
