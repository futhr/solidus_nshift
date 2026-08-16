# frozen_string_literal: true

module SolidusNshift
  module Checkout
    class PartialShipmentPayload
      def initialize(fulfillment:)
        @fulfillment = fulfillment
      end

      def call
        selection = @fulfillment.rate_selection
        address = @fulfillment.shipment.order.ship_address
        payload = {
          sessionId: selection.session_id,
          shippingOptionId: selection.external_option_id,
          orderId: @fulfillment.merchant_reference,
          receiver: {
            postalCode: address.zipcode,
            countryCode: address.country.iso
          }
        }
        if selection.selected_pickup_point_id.present?
          payload[:pickupPoint] = {id: selection.selected_pickup_point_id}
        end
        payload
      end
    end
  end
end
