# frozen_string_literal: true

module SolidusNshift
  module Delivery
    Shipment = Data.define(
      :id, :status, :order_number, :reference, :service_code, :tracking_number, :documents,
      :return_shipment, :consolidated
    ) do
      def self.from_hash(value)
        raise MalformedResponseError, "nShift Delivery shipment must be an object" unless value.is_a?(Hash)

        parcels = collection(value, "parcels")
        new(
          id: required(value, "id"),
          status: value["status"].to_s,
          order_number: value["orderNo"].to_s,
          reference: value["reference"].to_s,
          service_code: value["serviceId"].to_s,
          tracking_number: value["shipmentNo"].presence || parcels.filter_map { |parcel| parcel["parcelNo"].presence }.first,
          documents: collection(value, "prints").map { |document| Document.from_hash(document) },
          return_shipment: value["returnShipment"],
          consolidated: value["consolidated"]
        )
      end

      def self.required(value, key)
        result = value[key].to_s
        raise MalformedResponseError, "nShift Delivery shipment omitted #{key}" if result.empty?

        result
      end

      def self.collection(value, key)
        result = value[key]
        return [] if result.nil?
        unless result.is_a?(Array) && result.all? { |item| item.is_a?(Hash) }
          raise MalformedResponseError, "nShift Delivery shipment #{key} must be an array of objects"
        end

        result
      end
      private_class_method :required, :collection
    end
  end
end
