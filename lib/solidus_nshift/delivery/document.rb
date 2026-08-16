# frozen_string_literal: true

module SolidusNshift
  module Delivery
    Document = Data.define(:id, :description, :format, :href, :data) do
      def self.from_hash(value)
        new(
          id: value.fetch("id").to_s,
          description: value["description"].to_s,
          format: value["type"].to_s.downcase,
          href: value["href"],
          data: value["data"]
        )
      rescue KeyError
        raise MalformedResponseError, "nShift Delivery document omitted id"
      end

      def content_type
        (format == "pdf") ? "application/pdf" : "application/octet-stream"
      end
    end

    DocumentContent = Data.define(:body, :content_type)
  end
end
