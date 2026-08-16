# frozen_string_literal: true

module SolidusNshift
  module ShipmentData
    class ShipmentLocator
      def call(response, reference:)
        values = if response.is_a?(Array)
          response
        else
          response["shipments"] || response["items"] || response["results"] || response.dig("data", "shipments") || []
        end
        raise MalformedResponseError, "nShift Shipment Data search must contain an array" unless values.is_a?(Array)

        match = values.find do |value|
          next false unless value.is_a?(Hash)

          references(value).include?(reference.to_s)
        end
        return unless match

        uuid = match["shipmentUuid"] || match["uuid"] || match["id"]
        raise MalformedResponseError, "nShift Shipment Data result omitted shipment UUID" if uuid.to_s.empty?

        uuid.to_s
      end

      private

      def references(value)
        [
          value["orderNo"], value["orderNumber"], value["reference"],
          value["externalShipmentReference"], value.dig("shipment", "orderNo")
        ].compact.map(&:to_s)
      end
    end
  end
end
