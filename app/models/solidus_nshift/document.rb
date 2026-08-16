# frozen_string_literal: true

module SolidusNshift
  class Document < ::Spree::Base
    FORMATS = %w[pdf zpl].freeze

    self.table_name = "solidus_nshift_documents"

    belongs_to :fulfillment, class_name: "SolidusNshift::Fulfillment", inverse_of: :documents

    validates :provider_document_id, presence: true, uniqueness: {scope: :fulfillment_id}
    validates :format, inclusion: {in: FORMATS}
    validates :content_type, inclusion: {in: ["application/pdf", "application/octet-stream"]}

    def filename
      "nshift-#{fulfillment.merchant_reference.tr(":", "-")}-#{provider_document_id}.#{format}"
    end
  end
end
