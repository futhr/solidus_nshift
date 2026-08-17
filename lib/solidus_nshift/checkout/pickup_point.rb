# frozen_string_literal: true

module SolidusNshift
  module Checkout
    PickupPoint = Data.define(:id, :name, :address1, :postal_code, :city, :country_code) do
      def self.from_hash(value)
        raise MalformedResponseError, "nShift pickup point must be an object" unless value.is_a?(Hash)

        new(
          id: value["pickupPointId"],
          name: value["name"],
          address1: value["address1"],
          postal_code: value["postalCode"],
          city: value["city"],
          country_code: value["countryCode"]
        )
      end

      def to_h
        super.compact
      end
    end
  end
end
