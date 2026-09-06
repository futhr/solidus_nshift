# frozen_string_literal: true

module SolidusNshift
  class RateProvider
    Quote = Data.define(:option, :context_digest, :session_expires_at)

    def initialize(calculator:, package:)
      @calculator = calculator
      @package = package
      @connection = calculator.connection
    end

    def call
      unless @connection&.active? && @connection.checkout_enabled? && @connection.store_id == @package.shipment.order.store_id
        raise ConfigurationError, "nShift Checkout connection is unavailable for this store"
      end

      request = Solidus::PackageSerializer.new(package: @package, calculator: @calculator).call
      key = cache_key(request)
      session_and_options = cache.read(key)
      unless session_and_options && session_and_options.fetch(:session).expires_at > SolidusNshift.configuration.clock.call
        session_and_options = fetch_options(request)
        remaining = session_and_options.fetch(:session).expires_at - SolidusNshift.configuration.clock.call
        raise StaleSessionError, "nShift returned an expired checkout session" unless remaining.positive?

        cache.write(key, session_and_options, expires_in: [SolidusNshift.configuration.rate_cache_ttl, remaining].min)
      end
      session = session_and_options.fetch(:session)
      option = filter_options(session_and_options.fetch(:options)).min_by do |candidate|
        [candidate.price, candidate.label, candidate.external_id.to_s]
      end
      return [] unless option

      unless option.currency == @package.shipment.order.currency
        raise ValidationError, "nShift option currency does not match the Solidus order"
      end

      [Quote.new(option:, context_digest: request.context_digest, session_expires_at: session.expires_at)]
    end

    private

    def fetch_options(request)
      instrument("session") do
        client = @connection.checkout_client
        session = client.create_session(
          connection_id: @connection.preferred_checkout_connection_id,
          attributes: {}
        )
        options = client.shipping_options(
          session_id: session.id,
          payload: request.payload,
          currency: @package.shipment.order.currency
        )
        {session:, options:}
      end
    end

    def filter_options(options)
      allowed = @calculator.allowed_service_codes
      selected = allowed.empty? ? options : options.select { |option| allowed.include?(option.service_code) }
      case @calculator.preferred_option_kind
      when "pickup" then selected.select(&:pickup?)
      when "home" then selected.reject(&:pickup?)
      else selected
      end
    end

    def cache
      SolidusNshift.configuration.cache
    end

    def cache_key(request)
      "solidus_nshift:rates:#{@connection.cache_key_with_version}:#{request.context_digest}"
    end

    def instrument(operation)
      Instrumentation.request(
        api_family: "checkout",
        operation:,
        connection_id: @connection.id
      ) { yield }
    end
  end
end
