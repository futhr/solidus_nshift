# frozen_string_literal: true

require "solidus_core"
require "solidus_support"
require "solidus_nshift/shipment_extension"
require "solidus_nshift/shipping_rate_extension"
require "solidus_nshift/solidus/rate_estimator_extension"

module SolidusNshift
  class Engine < Rails::Engine
    include SolidusSupport::EngineExtensions

    isolate_namespace SolidusNshift
    engine_name "solidus_nshift"

    initializer "solidus_nshift.register_calculator", after: "spree.register.calculators" do |app|
      app.config.spree.calculators.shipping_methods << "Spree::Calculator::Shipping::NshiftCheckout"
    end

    initializer "solidus_nshift.filter_parameters" do |app|
      app.config.filter_parameters += %i[
        client_secret api_key api_key_id api_key_secret authorization
        checkout_client_secret delivery_api_key_id delivery_api_key_secret tracking_client_secret
        delivery_sender_name delivery_sender_address1 delivery_sender_address2 delivery_sender_zipcode
        delivery_sender_city delivery_sender_country delivery_sender_phone delivery_sender_email
      ]
    end

    initializer "solidus_nshift.backend_menu", after: "spree.load_config_initializers" do
      next unless defined?(Spree::Backend::Config)

      Spree::Backend::Config.menu_items << Spree::BackendConfiguration::MenuItem.new(
        label: :nshift,
        icon: "truck",
        url: "/solidus_nshift/admin/fulfillments",
        match_path: %r{/solidus_nshift/admin},
        condition: -> { can?(:admin, SolidusNshift::Fulfillment) }
      )
    end

    config.generators do |generator|
      generator.test_framework :rspec
    end

    config.to_prepare do
      unless Spree::ShippingRate < SolidusNshift::ShippingRateExtension
        Spree::ShippingRate.include(SolidusNshift::ShippingRateExtension)
      end
      unless Spree::Shipment < SolidusNshift::ShipmentExtension
        Spree::Shipment.include(SolidusNshift::ShipmentExtension)
      end

      estimator_class = Spree::Config.stock.estimator_class
      estimator_class = estimator_class.constantize if estimator_class.is_a?(String)
      extension = SolidusNshift::Solidus::RateEstimatorExtension
      estimator_class.prepend(extension) unless estimator_class < extension
    end

    initializer "solidus_nshift.core.pub_sub", after: "spree.core.pub_sub" do |app|
      app.reloader.to_prepare do
        SolidusNshift::OrderFinalizedSubscriber.install(Spree::Bus)
      end
    end
  end
end
