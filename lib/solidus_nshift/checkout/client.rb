# frozen_string_literal: true

require "json"
require "uri"

module SolidusNshift
  module Checkout
    class Client
      include Http::ResponseHandling

      BASE_URL = "https://api.nshiftportal.com/checkout"
      IDENTIFIER = /\A[0-9A-Za-z_.:-]{1,200}\z/

      def initialize(token_provider:, transport: Http::NetHttpTransport.new, base_url: BASE_URL,
        clock: -> { Time.now }, logger: nil)
        @token_provider = token_provider
        @transport = transport
        @base_url = base_url.to_s.delete_suffix("/")
        @clock = clock
        @logger = logger
        validate_base_url!
      end

      def create_session(connection_id:, attributes: {})
        body = request_json(
          :post,
          "/options/v1/sessions/#{identifier!(connection_id, "checkout connection ID")}",
          payload: attributes
        )
        session_id = body["sessionId"]
        raise MalformedResponseError, "nShift session response omitted sessionId" unless IDENTIFIER.match?(session_id.to_s)
        configuration_id = body["checkoutConfigurationId"]
        unless IDENTIFIER.match?(configuration_id.to_s)
          raise MalformedResponseError, "nShift session response omitted checkoutConfigurationId"
        end

        Session.new(
          id: session_id.to_s,
          expires_at: @clock.call + 4 * 60 * 60,
          checkout_configuration_id: configuration_id.to_s
        )
      end

      def shipping_options(session_id:, payload:, currency:)
        body = request_json(
          :post,
          "/options/v1/shipping-options/#{identifier!(session_id, "session ID")}",
          payload:
        )
        OptionNormalizer.new.call(body, session_id:, currency:)
      rescue ValidationError => error
        raise StaleSessionError.new(error.message, provider_code: error.provider_code) if stale_session?(error)

        raise
      end

      def create_partial_shipment(payload:, send_to_book_and_print: false)
        query = URI.encode_www_form(
          "send-to-book-and-print" => send_to_book_and_print,
          "extended-result" => !send_to_book_and_print
        )
        request_json(:post, "/shipments/v1/shipments?#{query}", payload:, mutation: true)
      end

      private

      def request_json(method, path, payload:, mutation: false, retried: false)
        token = @token_provider.token
        response = with_transport_errors(mutation:) do
          @transport.call(
            method:,
            url: "#{@base_url}#{path}",
            headers: {
              "Accept" => "application/json",
              "Authorization" => "Bearer #{token.value}",
              "Content-Type" => "application/json",
              "User-Agent" => "SolidusNshift/#{SolidusNshift::VERSION}"
            },
            body: JSON.generate(payload)
          )
        end
        if response.status == 401 && !retried
          @token_provider.invalidate!
          return request_json(method, path, payload:, mutation:, retried: true)
        end
        raise_for_response_status!(response, mutation:)
        body = parse_json(response, allow_empty: mutation)
        log(path, "success", response)
        body
      end

      def identifier!(value, name)
        normalized = value.to_s
        raise ValidationError, "#{name} has an invalid format" unless IDENTIFIER.match?(normalized)

        normalized
      end

      def stale_session?(error)
        %w[SESSION_EXPIRED SESSION_NOT_FOUND STALE_SESSION].include?(error.provider_code.to_s.upcase)
      end

      def validate_base_url!
        uri = URI.parse(@base_url)
        valid = uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
        raise ConfigurationError, "nShift Checkout base URL must be an absolute HTTPS URL" unless valid
      rescue URI::InvalidURIError
        raise ConfigurationError, "nShift Checkout base URL is invalid"
      end

      def log(path, result, response)
        @logger&.info(
          provider: "nshift",
          api_family: "checkout",
          operation: path.split("?").first,
          result:,
          provider_request_id: request_id(response.headers)
        )
      end
    end
  end
end
