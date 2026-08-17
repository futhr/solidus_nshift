# frozen_string_literal: true

module SolidusNshift
  class PersistDocuments
    def initialize(fulfillment:, documents:)
      @fulfillment = fulfillment
      @documents = documents
    end

    def call
      @documents.each do |provider_document|
        attributes = {
          description: provider_document.description,
          format: provider_document.format,
          content_type: provider_document.content_type
        }
        document = @fulfillment.documents.create_or_find_by!(provider_document_id: provider_document.id) do |record|
          record.assign_attributes(attributes)
        end
        document.update!(attributes)
      end
    end
  end
end
