# frozen_string_literal: true

require "digest"

module SolidusNshift
  module ShipmentData
    class EventNormalizer
      STATUS_CODES = {
        "CREATED" => "created",
        "BOOKED" => "created",
        "IN_TRANSIT" => "in_transit",
        "INTRANSIT" => "in_transit",
        "OUT_FOR_DELIVERY" => "out_for_delivery",
        "OUTFORDELIVERY" => "out_for_delivery",
        "DELIVERED" => "delivered",
        "POD" => "delivered",
        "EXCEPTION" => "exception",
        "DEVIATION" => "exception",
        "CANCELED" => "canceled",
        "CANCELLED" => "canceled"
      }.freeze

      def call(value)
        raise MalformedResponseError, "nShift Shipment Data event must be an object" unless value.is_a?(Hash)

        raw_code = (value["code"] || value["eventCode"] || value["status"] || value["statusCode"]).to_s
        timestamp = value["timestamp"] || value["eventTime"] || value["date"] || value["occurredAt"]
        occurred_at = Time.iso8601(timestamp.to_s)
        status = STATUS_CODES.fetch(raw_code.upcase.gsub(/[ -]/, "_"), "unknown")
        external_id = value["id"] || value["eventId"] || Digest::SHA256.hexdigest([raw_code, occurred_at.iso8601, value["description"]].join("|"))
        Event.new(
          external_id: external_id.to_s,
          code: raw_code,
          status:,
          occurred_at:,
          description: value["description"] || value["message"],
          raw_code:
        )
      rescue ArgumentError
        raise MalformedResponseError, "nShift Shipment Data event timestamp was invalid"
      end
    end
  end
end
