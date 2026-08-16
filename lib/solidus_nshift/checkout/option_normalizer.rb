# frozen_string_literal: true

module SolidusNshift
  module Checkout
    class OptionNormalizer
      def call(response, session_id:, currency:)
        values = if response.is_a?(Array)
          response
        else
          response["shippingOptions"] || response["options"] || response["items"] || []
        end
        raise MalformedResponseError, "nShift shipping options must be an array" unless values.is_a?(Array)

        values.map do |value|
          raise MalformedResponseError, "nShift shipping option must be an object" unless value.is_a?(Hash)

          ShippingOption.from_hash(value, session_id:, default_currency: currency)
        end.group_by(&:external_id).values.map do |duplicates|
          duplicates.min_by { |option| [option.price, option.service_code.to_s, option.label] }
        end.sort_by { |option| [option.price, option.label, option.external_id.to_s] }
      end
    end
  end
end
