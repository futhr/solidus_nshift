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
      request = Solidus::PackageSerializer.new(package: @package, calculator: @calculator).call
      session_and_options = cache.fetch(cache_key(request), expires_in: SolidusNshift.configuration.rate_cache_ttl) do
        fetch_options(request)
      end
      session = session_and_options.fetch(:session)
      option = filter_options(session_and_options.fetch(:options)).min_by do |candidate|
        [candidate.price, candidate.label, candidate.external_id.to_s]
      end
      return [] unless option

      [option].map do |option|
        unless option.currency == @package.shipment.order.currency
          raise ValidationError, "nShift option currency does not match the Solidus order"
        end

        Quote.new(option:, context_digest: request.context_digest, session_expires_at: session.expires_at)
      end
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
      "solidus_nshift:rates:#{@connection.id}:#{request.context_digest}"
    end

    def instrument(operation)
      ActiveSupport::Notifications.instrument(
        "solidus_nshift.request",
        api_family: "checkout",
        operation:,
        connection_id: @connection.id
      ) { yield }
    end
  end
end
