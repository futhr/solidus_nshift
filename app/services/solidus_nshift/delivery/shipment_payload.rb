# frozen_string_literal: true

module SolidusNshift
  module Delivery
    class ShipmentPayload
      def initialize(fulfillment:)
        @fulfillment = fulfillment
        @shipment = fulfillment.shipment
        @selection = fulfillment.rate_selection
        @connection = fulfillment.connection
      end

      def call
        shipment = {
          developerId: @connection.preferred_delivery_developer_id,
          test: @connection.preferred_delivery_test_mode,
          sender: sender,
          receiver: receiver,
          service: {id: @selection.service_code},
          parcels: parcels,
          orderNo: @fulfillment.merchant_reference,
          externalShipmentReference: @fulfillment.merchant_reference,
          senderReference: @shipment.number.to_s.first(17)
        }
        shipment[:agent] = agent if @selection.selected_pickup_point_id.present?
        {
          printConfig: {
            target1Media: @connection.preferred_delivery_label_media,
            target1Type: @connection.preferred_delivery_label_format
          },
          shipment:
        }
      end

      private

      def sender
        {
          quickId: @connection.preferred_delivery_sender_quick_id,
          name: @connection.preferred_delivery_sender_name,
          address1: @connection.preferred_delivery_sender_address1,
          address2: @connection.preferred_delivery_sender_address2,
          zipcode: @connection.preferred_delivery_sender_zipcode,
          city: @connection.preferred_delivery_sender_city,
          country: @connection.preferred_delivery_sender_country,
          phone: @connection.preferred_delivery_sender_phone,
          email: @connection.preferred_delivery_sender_email
        }.compact_blank
      end

      def receiver
        address = @shipment.order.ship_address
        raise ValidationError, "nShift shipment requires a shipping address" unless address

        country = address.country&.iso
        unless address.name.present? && address.city.present? && country.present?
          raise ValidationError, "nShift receiver name, city, and country are required"
        end

        {
          name: address.name,
          careOf: address.company,
          address1: address.address1,
          address2: address.address2,
          zipcode: address.zipcode,
          city: address.city,
          state: address.state_text,
          country:,
          phone: address.phone,
          email: @shipment.order.email
        }.compact_blank
      end

      def agent
        point = @selection.selected_pickup_point.stringify_keys
        {
          quickId: @selection.selected_pickup_point_id,
          name: point["name"],
          address1: point["address1"],
          zipcode: point["postal_code"],
          city: point["city"],
          country: point["country_code"]
        }.compact_blank
      end

      def parcels
        values = build_parcels
        unless values.is_a?(Array) && values.any?
          raise ValidationError, "nShift parcel builder must return a non-empty array"
        end

        values.map do |value|
          parcel = value.to_h.symbolize_keys
          weight = BigDecimal(parcel.fetch(:weight).to_s)
          raise ValidationError, "nShift parcel weight must be positive" unless weight.finite? && weight.positive?
          copies = positive_integer!(parcel.fetch(:copies, 1))

          {
            copies:,
            weight: JsonDecimal.new(weight),
            contents: parcel.fetch(:contents, "Merchandise").to_s,
            valuePerParcel: true
          }
        rescue ArgumentError, TypeError, KeyError, NoMethodError
          raise ValidationError, "nShift parcel data is invalid"
        end
      end

      def build_parcels
        builder = SolidusNshift.configuration.parcel_builder
        accepts_weight_unit = builder.parameters.any? do |kind, name|
          kind == :keyrest || (%i[key keyreq].include?(kind) && name == :weight_unit)
        end
        return builder.call(@shipment) unless accepts_weight_unit

        builder.call(@shipment, weight_unit:)
      end

      def weight_unit
        calculator = @selection.shipping_rate.shipping_method.calculator
        calculator.preferred_weight_unit
      end

      def positive_integer!(value)
        integer = Integer(value)
        raise ArgumentError unless integer.positive?
        raise ArgumentError if value.is_a?(Numeric) && value != integer

        integer
      end
    end
  end
end
