# frozen_string_literal: true

module SolidusNshift
  module Delivery
    Shipment = Data.define(:id, :status, :order_number, :reference, :service_code, :tracking_number, :documents, :raw) do
      def self.from_hash(value)
        new(
          id: required(value, "id"),
          status: value["status"].to_s,
          order_number: value["orderNo"].to_s,
          reference: value["reference"].to_s,
          service_code: value["serviceId"].to_s,
          tracking_number: value["shipmentNo"] || Array(value["parcels"]).filter_map { |parcel| parcel["parcelNo"] }.first,
          documents: Array(value["prints"]).map { |document| Document.from_hash(document) },
          raw: {
            "normalShipment" => value["normalShipment"],
            "returnShipment" => value["returnShipment"],
            "consolidated" => value["consolidated"]
          }.compact.freeze
        )
      end

      def self.required(value, key)
        result = value[key].to_s
        raise MalformedResponseError, "nShift Delivery shipment omitted #{key}" if result.empty?

        result
      end
      private_class_method :required
    end
  end
end
