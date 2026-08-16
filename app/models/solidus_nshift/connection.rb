# frozen_string_literal: true

module SolidusNshift
  class Connection < ::Spree::Base
    include Spree::Preferences::Persistable

    self.table_name = "solidus_nshift_connections"

    belongs_to :store, class_name: "Spree::Store"
    has_many :rate_selections, class_name: "SolidusNshift::RateSelection", dependent: :restrict_with_error
    has_many :fulfillments, class_name: "SolidusNshift::Fulfillment", dependent: :restrict_with_error

    preference :checkout_client_id, :string
    preference :checkout_client_secret, :encrypted_string
    preference :checkout_connection_id, :string
    preference :delivery_api_key_id, :encrypted_string
    preference :delivery_api_key_secret, :encrypted_string
    preference :delivery_developer_id, :string
    preference :delivery_sender_quick_id, :string
    preference :delivery_test_mode, :boolean, default: true
    preference :tracking_client_id, :string
    preference :tracking_client_secret, :encrypted_string

    validates :name, presence: true, uniqueness: {scope: :store_id}
    validate :at_least_one_capability
    validate :checkout_configuration, if: :checkout_enabled?
    validate :delivery_configuration, if: :delivery_enabled?
    validate :tracking_configuration, if: :tracking_enabled?

    scope :enabled, -> { where(active: true) }

    def checkout_client
      Checkout::Client.new(
        token_provider: oauth_token_provider(
          client_id: preferred_checkout_client_id,
          client_secret: preferred_checkout_client_secret,
          namespace: "checkout"
        ),
        transport: SolidusNshift.configuration.transport_factory.call,
        clock: SolidusNshift.configuration.clock,
        logger: SolidusNshift.configuration.logger.call
      )
    end

    def delivery_client
      Delivery::Client.new(
        api_key_id: preferred_delivery_api_key_id,
        api_key_secret: preferred_delivery_api_key_secret,
        transport: SolidusNshift.configuration.transport_factory.call,
        logger: SolidusNshift.configuration.logger.call
      )
    end

    def shipment_data_client
      ShipmentData::Client.new(
        token_provider: oauth_token_provider(
          client_id: preferred_tracking_client_id,
          client_secret: preferred_tracking_client_secret,
          namespace: "shipment_data"
        ),
        transport: SolidusNshift.configuration.transport_factory.call,
        logger: SolidusNshift.configuration.logger.call
      )
    end

    def inspect
      "#<#{self.class.name} id=#{id.inspect} store_id=#{store_id.inspect} name=#{name.inspect}>"
    end

    private

    def oauth_token_provider(client_id:, client_secret:, namespace:)
      OAuth::TokenProvider.new(
        client_id:,
        client_secret:,
        cache: SolidusNshift.configuration.cache,
        clock: SolidusNshift.configuration.clock,
        sleeper: SolidusNshift.configuration.sleeper,
        transport: SolidusNshift.configuration.transport_factory.call,
        logger: SolidusNshift.configuration.logger.call,
        cache_namespace: "connection:#{id}:#{namespace}"
      )
    end

    def at_least_one_capability
      return if checkout_enabled? || delivery_enabled? || tracking_enabled?

      errors.add(:base, "enable at least one nShift capability")
    end

    def checkout_configuration
      require_preferences(:checkout_client_id, :checkout_client_secret, :checkout_connection_id)
    end

    def delivery_configuration
      require_preferences(:delivery_api_key_id, :delivery_api_key_secret, :delivery_developer_id, :delivery_sender_quick_id)
    end

    def tracking_configuration
      require_preferences(:tracking_client_id, :tracking_client_secret)
    end

    def require_preferences(*names)
      names.each do |name|
        errors.add("preferred_#{name}", "can't be blank") if public_send("preferred_#{name}").blank?
      end
    end
  end
end
