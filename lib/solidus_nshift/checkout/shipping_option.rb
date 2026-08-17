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
        pickup_values = value.fetch("pickupPoints", [])
        unless pickup_values.is_a?(Array)
          raise MalformedResponseError, "nShift shipping option pickupPoints must be an array"
        end
        delivery_time = value["deliveryTime"]
        unless delivery_time.nil? || delivery_time.is_a?(Hash)
          raise MalformedResponseError, "nShift shipping option deliveryTime must be an object"
        end

        new(
          external_id: value["optionId"],
          service_code: value["sourceSystemProductId"],
          carrier_code: value["sourceSystemCarrierId"],
          carrier_name: value["carrierName"],
          label: value["name"],
          price: decimal!(value["price"], "price"),
          currency: default_currency.to_s.upcase,
          delivery_estimate: delivery_time&.fetch("description", nil),
          pickup_points: pickup_values.map { |point| PickupPoint.from_hash(point) },
          metadata: {
            "carrierProductId" => value["carrierProductId"],
            "carrierProductSourceSystem" => value["carrierProductSourceSystem"],
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
