# frozen_string_literal: true

module SolidusNshift
  module Checkout
    class OptionNormalizer
      def call(response, session_id:, currency:)
        raise MalformedResponseError, "nShift shipping-options response must be an object" unless response.is_a?(Hash)

        values = response["options"]
        raise MalformedResponseError, "nShift shipping options must be an array" unless values.is_a?(Array)

        options = values.filter_map do |value|
          raise MalformedResponseError, "nShift shipping option must be an object" unless value.is_a?(Hash)
          if value.key?("valid") && ![true, false].include?(value["valid"])
            raise MalformedResponseError, "nShift shipping option valid flag must be boolean"
          end
          next if value["valid"] == false

          ShippingOption.from_hash(value, session_id:, default_currency: currency)
        end
        if options.map(&:external_id).uniq.length != options.length
          raise MalformedResponseError, "nShift shipping options contained duplicate optionId values"
        end

        options.sort_by { |option| [option.price, option.label, option.external_id.to_s] }
      end
    end
  end
end
