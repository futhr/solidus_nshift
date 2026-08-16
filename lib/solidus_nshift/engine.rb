# frozen_string_literal: true

require "solidus_core"
require "solidus_support"

module SolidusNshift
  class Engine < Rails::Engine
    include SolidusSupport::EngineExtensions

    isolate_namespace SolidusNshift
    engine_name "solidus_nshift"

    initializer "solidus_nshift.register_calculator", after: "spree.register.calculators" do |app|
      app.config.spree.calculators.shipping_methods << "Spree::Calculator::Shipping::NshiftCheckout"
    end

    initializer "solidus_nshift.install_estimator", after: "spree.core.environment" do
      Spree::Config.stock.estimator_class = "SolidusNshift::Solidus::RateEstimator"
    end

    initializer "solidus_nshift.filter_parameters" do |app|
      app.config.filter_parameters += %i[
        client_secret api_key api_key_id api_key_secret authorization
        checkout_client_secret delivery_api_key_id delivery_api_key_secret tracking_client_secret
      ]
    end

    config.generators do |generator|
      generator.test_framework :rspec
    end

    config.to_prepare do
      unless Spree::ShippingRate < SolidusNshift::ShippingRateExtension
        Spree::ShippingRate.include(SolidusNshift::ShippingRateExtension)
      end
    end
  end
end
