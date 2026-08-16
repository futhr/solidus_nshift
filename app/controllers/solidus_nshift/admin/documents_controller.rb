# frozen_string_literal: true

module SolidusNshift
  module Admin
    class DocumentsController < BaseController
      def show
        document = Document.includes(fulfillment: :connection).find(params[:id])
        content = DownloadDocument.new(document:).call
        send_data(
          content.body,
          type: content.content_type,
          disposition: "attachment",
          filename: document.filename
        )
      end
    end
  end
end
