# frozen_string_literal: true

module SolidusNshift
  module Solidus
    class PackageSerializer
      def initialize(package:, calculator:)
        @package = package
        @calculator = calculator
      end

      def call
        Checkout::PackageRequestBuilder.new(
          receiver: receiver,
          items: items,
          currency: order.currency,
          locale: @calculator.preferred_locale,
          cart_price: order.item_total,
          weight_unit: @calculator.preferred_weight_unit,
          dimension_unit: @calculator.preferred_dimension_unit,
          context: {
            store_id: order.store_id,
            connection_id: @calculator.preferred_connection_id,
            shipment_id: @package.shipment&.id,
            stock_location_id: @package.stock_location&.id,
            item_ids: @package.contents.map { |content| [content.variant.id, content.quantity] }
          }
        ).call
      end

      def self.default_parcels(shipment)
        package = shipment.to_package
        weight = package.contents.sum(BigDecimal("0")) do |content|
          BigDecimal(content.variant.weight.to_s) * content.quantity
        end
        [{weight: weight, copies: 1, contents: "Merchandise"}]
      rescue ArgumentError
        raise ValidationError, "shipment contains an invalid weight"
      end

      private

      def order
        @package.shipment&.order || @package.order || raise(ValidationError, "package is not attached to an order")
      end

      def receiver
        address = order.ship_address || raise(ValidationError, "order shipping address is required")
        {
          postal_code: address.zipcode,
          country_code: address.country&.iso
        }
      end

      def items
        @package.contents.map do |content|
          variant = content.variant
          {
            quantity: content.quantity,
            weight: variant.weight,
            length: variant.depth,
            width: variant.width,
            height: variant.height
          }
        end
      end
    end
  end
end
