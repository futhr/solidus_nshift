# frozen_string_literal: true

module SolidusNshift
  module Delivery
    Document = Data.define(:id, :description, :format, :href, :data) do
      def self.from_hash(value)
        raise MalformedResponseError, "nShift Delivery document must be an object" unless value.is_a?(Hash)

        id = value.fetch("id").to_s
        raise MalformedResponseError, "nShift Delivery document omitted id" if id.empty?

        new(
          id:,
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
