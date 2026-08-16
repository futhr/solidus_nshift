# frozen_string_literal: true

module SolidusNshift
  module Checkout
    PickupPoint = Data.define(:id, :name, :address1, :postal_code, :city, :country_code) do
      def self.from_hash(value)
        new(
          id: value["id"] || value["pickupPointId"],
          name: value["name"],
          address1: value["address1"] || value["address"],
          postal_code: value["postalCode"] || value["zipcode"],
          city: value["city"],
          country_code: value["countryCode"] || value["country"]
        )
      end

      def to_h
        super.compact
      end
    end
  end
end
