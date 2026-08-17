# frozen_string_literal: true

require "digest"
require "json"

module SolidusNshift
  module Checkout
    PackageRequest = Data.define(:payload, :context_digest)

    class PackageRequestBuilder
      def initialize(receiver:, items:, currency:, locale:, cart_price:, weight_unit:, dimension_unit:, context: {})
        @weight_unit = weight_unit
        @dimension_unit = dimension_unit
        @receiver = normalized_hash(receiver, "receiver")
        @items = normalize_items(items)
        @currency = currency.to_s.upcase
        @locale = locale.to_s.downcase
        @cart_price = decimal!(cart_price, "cart price")
        @context = context
        validate!
      end

      def call
        package_weight = @items.sum(BigDecimal("0")) do |item|
          Units.weight_to_kg(item.fetch(:weight), @weight_unit) * item.fetch(:quantity)
        end
        raise ValidationError, "package weight must be positive" unless package_weight.positive?

        package_volume = total_volume
        payload = {
          currencyCode: @currency,
          languageCode: @locale,
          totalWeightKg: JsonDecimal.new(package_weight),
          receiver: {
            postalCode: @receiver.fetch(:postal_code).to_s,
            country: @receiver.fetch(:country_code).to_s.upcase
          },
          packages: [{weightKg: JsonDecimal.new(package_weight), volumeCm3: package_volume && JsonDecimal.new(package_volume)}],
          variables: {cartPrice: JsonDecimal.new(@cart_price)}
        }
        digest_payload = deep_plain(payload).merge("context" => deep_plain(@context))
        PackageRequest.new(payload:, context_digest: Digest::SHA256.hexdigest(JSON.generate(digest_payload)))
      end

      private

      def total_volume
        return if @items.any? { |item| %i[length width height].any? { |key| item[key].nil? } }

        @items.sum(BigDecimal("0")) do |item|
          dimensions = %i[length width height].map { |key| Units.length_to_cm(item.fetch(key), @dimension_unit) }
          dimensions.reduce(:*) * item.fetch(:quantity)
        end
      end

      def deep_plain(value)
        case value
        when JsonDecimal then value.value.to_s("F")
        when Hash
          value.sort_by { |key, _item| key.to_s }.to_h { |key, item| [key.to_s, deep_plain(item)] }
        when Array then value.map { |item| deep_plain(item) }
        else value
        end
      end

      def decimal!(value, name)
        decimal = BigDecimal(value.to_s)
        raise ArgumentError unless decimal.finite? && !decimal.negative?

        decimal
      rescue ArgumentError, TypeError
        raise ValidationError, "#{name} must be a non-negative decimal"
      end

      def validate!
        raise ValidationError, "receiver postal code is required" if @receiver[:postal_code].to_s.empty?
        raise ValidationError, "receiver country must be ISO 3166-1 alpha-2" unless /\A[A-Z]{2}\z/.match?(@receiver[:country_code].to_s.upcase)
        raise ValidationError, "currency must be ISO 4217" unless /\A[A-Z]{3}\z/.match?(@currency)
        raise ValidationError, "locale must be a two-letter language code" unless /\A[a-z]{2}\z/.match?(@locale)
        raise ValidationError, "package must contain at least one item" if @items.empty?
      end

      def normalize_items(items)
        raise ValidationError, "items must be an array" unless items.is_a?(Array)

        items.map do |item|
          normalized = normalized_hash(item, "item")
          normalized[:quantity] = positive_integer!(normalized[:quantity])
          Units.weight_to_kg(normalized.fetch(:weight), @weight_unit)
          %i[length width height].each do |key|
            Units.length_to_cm(normalized[key], @dimension_unit) unless normalized[key].nil?
          end
          normalized
        rescue KeyError
          raise ValidationError, "item weight is required"
        end
      end

      def normalized_hash(value, name)
        raise ValidationError, "#{name} must be an object" unless value.respond_to?(:to_h)

        value.to_h.transform_keys(&:to_sym)
      rescue TypeError, NoMethodError
        raise ValidationError, "#{name} must be an object"
      end

      def positive_integer!(value)
        integer = Integer(value)
        raise ArgumentError unless integer.positive?
        raise ArgumentError if value.is_a?(Numeric) && value != integer

        integer
      rescue ArgumentError, TypeError
        raise ValidationError, "item quantity must be a positive integer"
      end
    end
  end
end
