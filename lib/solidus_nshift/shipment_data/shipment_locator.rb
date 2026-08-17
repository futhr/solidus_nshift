# frozen_string_literal: true

module SolidusNshift
  module ShipmentData
    class ShipmentLocator
      def call(response, reference:)
        raise MalformedResponseError, "nShift Shipment Data search must contain an array" unless response.is_a?(Array)

        matches = response.select do |value|
          raise MalformedResponseError, "nShift Shipment Data result must be an object" unless value.is_a?(Hash)

          [value["orderNumber"], value["additionalReference"]].compact.map(&:to_s).include?(reference.to_s)
        end
        if matches.length > 1
          raise ShipmentConflictError, "nShift Shipment Data found multiple shipments for the merchant reference"
        end
        match = matches.first
        return unless match

        uuid = match["uuid"]
        raise MalformedResponseError, "nShift Shipment Data result omitted shipment UUID" if uuid.to_s.empty?

        uuid.to_s
      end
    end
  end
end
