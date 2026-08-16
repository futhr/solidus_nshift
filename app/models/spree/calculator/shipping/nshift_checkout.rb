# frozen_string_literal: true

module Spree
  module Calculator::Shipping
    class NshiftCheckout < ShippingCalculator
      ADMIN_PREFERENCE_NAMES = %i[
        connection_id allowed_service_codes option_kind weight_unit dimension_unit locale
      ].freeze
      WEIGHT_UNITS = %w[kg g lb oz].freeze
      DIMENSION_UNITS = %w[cm mm m in].freeze
      OPTION_KINDS = %w[any home pickup].freeze

      preference :connection_id, :integer
      preference :allowed_service_codes, :string
      preference :option_kind, :string, default: "any"
      preference :weight_unit, :string, default: "kg"
      preference :dimension_unit, :string, default: "cm"
      preference :locale, :string, default: "en"

      validate :nshift_configuration

      def self.description
        I18n.t("solidus_nshift.checkout_calculator", default: "nShift Checkout")
      end

      def admin_form_preference_names
        ADMIN_PREFERENCE_NAMES
      end

      def available?(_package)
        connection&.active? && connection.checkout_enabled?
      end

      def compute_package(_package)
        nil
      end

      def rate_quotes(package)
        return [] unless available?(package)

        SolidusNshift::RateProvider.new(calculator: self, package:).call
      rescue SolidusNshift::Error => error
        ActiveSupport::Notifications.instrument(
          "solidus_nshift.request",
          api_family: "checkout",
          result: error.class.name,
          connection_id: preferred_connection_id
        )
        []
      end

      def connection
        return if preferred_connection_id.to_i.zero?

        SolidusNshift::Connection.find_by(id: preferred_connection_id)
      end

      def allowed_service_codes
        preferred_allowed_service_codes.to_s.split(/[\s,]+/).reject(&:empty?).uniq
      end

      private

      def nshift_configuration
        errors.add(:preferred_connection_id, "must reference an active Checkout connection") unless available?(nil)
        errors.add(:preferred_weight_unit, "is not supported") unless WEIGHT_UNITS.include?(preferred_weight_unit)
        errors.add(:preferred_dimension_unit, "is not supported") unless DIMENSION_UNITS.include?(preferred_dimension_unit)
        errors.add(:preferred_option_kind, "is not supported") unless OPTION_KINDS.include?(preferred_option_kind)
        errors.add(:preferred_locale, "must be a two-letter language code") unless /\A[a-z]{2}\z/.match?(preferred_locale)
      end
    end
  end
end
