# frozen_string_literal: true

module SolidusNshift
  class DownloadDocument
    MAX_BYTES = 25 * 1024 * 1024

    def initialize(document:)
      @document = document
    end

    def call
      fulfillment = @document.fulfillment
      content = fulfillment.connection.delivery_client.download_document(
        shipment_id: fulfillment.provider_shipment_id,
        document_id: @document.provider_document_id,
        format: @document.format
      )
      raise DocumentError, "nShift document exceeded the download limit" if content.body.bytesize > MAX_BYTES

      content
    end
  end
end
