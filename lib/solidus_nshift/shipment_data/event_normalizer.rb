# frozen_string_literal: true

module SolidusNshift
  module ShipmentData
    class EventNormalizer
      def call(value)
        raise MalformedResponseError, "nShift Shipment Data event must be an object" unless value.is_a?(Hash)

        external_id = value["uuid"].to_s
        raise MalformedResponseError, "nShift Shipment Data event omitted UUID" if external_id.empty?

        normalized_status_id = integer_or_nil(value["normalizedStatusId"])
        normalized_status_name = value["normalizedStatusName"].to_s
        raise MalformedResponseError, "nShift Shipment Data event omitted normalized status" if normalized_status_name.empty?

        occurred_at = Time.iso8601(value["date"].to_s)
        raw_code = normalized_status_id&.to_s || normalized_status_name
        Event.new(
          external_id:,
          code: raw_code,
          status: normalized_status(normalized_status_id),
          occurred_at:,
          description: value["configurationName"],
          raw_code:
        )
      rescue ArgumentError, TypeError
        raise MalformedResponseError, "nShift Shipment Data event timestamp was invalid"
      end

      private

      def integer_or_nil(value)
        return if value.nil?

        Integer(value)
      rescue ArgumentError, TypeError
        raise MalformedResponseError, "nShift Shipment Data normalized status ID was invalid"
      end

      def normalized_status(status_id)
        case status_id
        when 1000..1999 then "created"
        when 2001 then "out_for_delivery"
        when 2000..2999 then "in_transit"
        when 3000, 3001, 3003 then "delivered"
        when 6004, 7001 then "canceled"
        when 3002, 5000..7999 then "exception"
        else "unknown"
        end
      end
    end
  end
end
