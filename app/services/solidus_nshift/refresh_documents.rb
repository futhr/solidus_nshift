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
        PersistDocuments.new(fulfillment: @fulfillment, documents: values).call
      end
      @fulfillment.documents.reload
    end
  end
end
