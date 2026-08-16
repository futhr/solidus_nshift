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
        payload = {
          developerId: @connection.preferred_delivery_developer_id,
          test: @connection.preferred_delivery_test_mode,
          sender: {quickId: @connection.preferred_delivery_sender_quick_id},
          receiver: receiver,
          service: {id: @selection.service_code},
          parcels: parcels,
          orderNo: @fulfillment.merchant_reference,
          externalShipmentReference: @fulfillment.merchant_reference,
          senderReference: @shipment.number.to_s.first(17)
        }
        payload[:agent] = agent if @selection.selected_pickup_point_id.present?
        payload
      end

      private

      def receiver
        address = @shipment.order.ship_address
        {
          name: address.name,
          careOf: address.company,
          address1: address.address1,
          address2: address.address2,
          zipcode: address.zipcode,
          city: address.city,
          state: address.state_text,
          country: address.country.iso,
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
        values = SolidusNshift.configuration.parcel_builder.call(@shipment)
        raise ValidationError, "nShift shipment must contain at least one parcel" if values.blank?

        values.map do |value|
          parcel = value.to_h.symbolize_keys
          weight = BigDecimal(parcel.fetch(:weight).to_s)
          raise ValidationError, "nShift parcel weight must be non-negative" if weight.negative?

          {
            copies: Integer(parcel.fetch(:copies, 1)),
            weight: JsonDecimal.new(weight),
            contents: parcel.fetch(:contents, "Merchandise").to_s,
            valuePerParcel: true
          }
        rescue ArgumentError, TypeError, KeyError
          raise ValidationError, "nShift parcel data is invalid"
        end
      end
    end
  end
end
