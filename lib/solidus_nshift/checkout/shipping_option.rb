# frozen_string_literal: true

require "bigdecimal"

module SolidusNshift
  module Checkout
    class ShippingOption
      ATTRIBUTES = %i[
        external_id service_code carrier_code carrier_name label price currency
        delivery_estimate pickup_points metadata session_id
      ].freeze
      attr_reader(*ATTRIBUTES)

      def initialize(**attributes)
        ATTRIBUTES.each { |name| instance_variable_set("@#{name}", attributes.fetch(name)) }
        validate!
        freeze
      end

      def self.from_hash(value, session_id:, default_currency: nil)
        price_value = value["price"]
        price_value = price_value["value"] || price_value["amount"] if price_value.is_a?(Hash)
        service = value["service"] || value["carrierService"] || {}
        carrier = value["carrier"] || {}
        pickup_values = value["pickupPoints"] || value["servicePoints"] || []
        new(
          external_id: value["optionId"] || value["id"],
          service_code: value["sourceSystemProductId"] || value["serviceCode"] || service["id"] || service["code"],
          carrier_code: value["sourceSystemCarrierId"] || value["carrierCode"] || carrier["id"] || carrier["code"],
          carrier_name: value["carrierName"] || carrier["name"],
          label: value["name"] || value["label"] || value["title"] || value["priceDescription"],
          price: decimal!(price_value, "price"),
          currency: (value["currencyCode"] || value["currency"] || default_currency).to_s.upcase,
          delivery_estimate: value["deliveryTime"] || value["deliveryEstimate"] || value["deliveryWindow"],
          pickup_points: Array(pickup_values).map { |point| PickupPoint.from_hash(point) },
          metadata: {
            "code" => value["code"],
            "sourceSystemCarrierId" => value["sourceSystemCarrierId"],
            "sourceSystemProductId" => value["sourceSystemProductId"]
          }.compact.freeze,
          session_id: session_id.to_s
        )
      end

      def pickup?
        pickup_points.any?
      end

      def to_h
        ATTRIBUTES.to_h { |name| [name, public_send(name)] }
      end

      def self.decimal!(value, name)
        decimal = BigDecimal(value.to_s)
        raise ArgumentError unless decimal.finite? && !decimal.negative?

        decimal
      rescue ArgumentError, TypeError
        raise MalformedResponseError, "nShift shipping option #{name} was not a non-negative decimal"
      end
      private_class_method :decimal!

      private

      def validate!
        raise MalformedResponseError, "nShift shipping option omitted optionId" if external_id.to_s.empty?
        raise MalformedResponseError, "nShift shipping option omitted service code" if service_code.to_s.empty?
        raise MalformedResponseError, "nShift shipping option omitted label" if label.to_s.empty?
        raise MalformedResponseError, "nShift shipping option currency must be ISO 4217" unless /\A[A-Z]{3}\z/.match?(currency)
        raise MalformedResponseError, "nShift shipping option omitted session ID" if session_id.empty?
        raise MalformedResponseError, "nShift pickup point omitted ID" if pickup_points.any? { |point| point.id.to_s.empty? }
      end
    end
  end
end
