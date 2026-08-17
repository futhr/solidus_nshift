# frozen_string_literal: true

module SolidusNshift
  module Solidus
    module RateEstimatorExtension
      private

      def calculate_shipping_rates(package)
        super + nshift_shipping_rates(package)
      end

      def nshift_shipping_rates(package)
        nshift_shipping_methods(package).flat_map do |shipping_method|
          shipping_method.calculator.rate_quotes(package).map do |quote|
            build_nshift_rate(shipping_method, package, quote)
          end
        end
      end

      def nshift_shipping_methods(package)
        shipping_methods(package).select do |method|
          method.calculator.is_a?(::Spree::Calculator::Shipping::NshiftCheckout)
        end
      end

      def build_nshift_rate(shipping_method, package, quote)
        option = quote.option
        rate = shipping_method.shipping_rates.new(cost: option.price, shipment: package.shipment)
        rate.build_nshift_selection(
          connection: shipping_method.calculator.connection,
          session_id: option.session_id,
          external_option_id: option.external_id,
          service_code: option.service_code,
          carrier_code: option.carrier_code,
          carrier_name: option.carrier_name,
          label: option.label,
          amount: option.price,
          currency: option.currency,
          delivery_estimate: option.delivery_estimate,
          context_digest: quote.context_digest,
          pickup_points: option.pickup_points.map { |point| point.to_h.stringify_keys },
          provider_metadata: option.metadata,
          session_expires_at: quote.session_expires_at
        )
        add_nshift_taxes(rate, package)
        rate
      end

      def add_nshift_taxes(rate, package)
        calculator = ::Spree::Config.shipping_rate_tax_calculator_class.new(package.shipment.order)
        calculator.calculate(rate).each do |tax|
          rate.taxes.new(amount: tax.amount, tax_rate: tax.tax_rate)
        end
      end
    end
  end
end
