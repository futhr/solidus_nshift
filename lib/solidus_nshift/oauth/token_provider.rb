# frozen_string_literal: true

require "digest"
require "json"
require "uri"

module SolidusNshift
  module OAuth
    class TokenProvider
      include Http::ResponseHandling

      TOKEN_URL = "https://account.nshiftportal.com/idp/connect/token"
      DEFAULT_SAFETY_MARGIN = 60
      DEFAULT_ATTEMPTS = 3

      def initialize(client_id:, client_secret:, cache:, clock: -> { Time.now },
        sleeper: ->(seconds) { sleep(seconds) }, transport: Http::NetHttpTransport.new,
        safety_margin: DEFAULT_SAFETY_MARGIN, attempts: DEFAULT_ATTEMPTS, logger: nil,
        cache_namespace: "default")
        @client_id = client_id.to_s
        @client_secret = client_secret.to_s
        @cache = cache
        @clock = clock
        @sleeper = sleeper
        @transport = transport
        @safety_margin = Integer(safety_margin)
        @attempts = Integer(attempts)
        @logger = logger
        @cache_namespace = cache_namespace.to_s
        @mutex = Mutex.new
        validate_configuration!
      end

      def token(force: false)
        invalidate! if force
        cached = cached_token
        return cached if cached

        @mutex.synchronize { cached_token || acquire_with_backoff }
      end

      def invalidate!
        @cache.delete(cache_key)
      end

      private

      def cached_token
        raw = @cache.read(cache_key)
        return unless raw
        unless raw.is_a?(Hash)
          invalidate!
          return
        end

        token = Token.new(value: raw.fetch("value"), expires_at: Time.at(raw.fetch("expires_at")).utc)
        token if token.valid?(at: @clock.call, safety_margin: @safety_margin)
      rescue KeyError, TypeError, ArgumentError
        invalidate!
        nil
      end

      def acquire_with_backoff
        last_error = nil
        @attempts.times do |attempt|
          return acquire
        rescue RateLimitError, ProviderUnavailableError, TransportError => error
          last_error = error
          break if attempt == @attempts - 1

          @sleeper.call(0.25 * (2**attempt))
        end
        raise TokenError.new("nShift OAuth token acquisition failed", provider_code: last_error&.provider_code)
      end

      def acquire
        response = with_transport_errors do
          @transport.call(
            method: :post,
            url: TOKEN_URL,
            headers: {"Accept" => "application/json", "Content-Type" => "application/x-www-form-urlencoded"},
            body: URI.encode_www_form(
              grant_type: "client_credentials",
              client_id: @client_id,
              client_secret: @client_secret
            )
          )
        end
        raise_for_response_status!(response)
        body = parse_json(response)
        value = body["access_token"].to_s
        expires_in = Integer(body["expires_in"])
        raise MalformedResponseError, "nShift OAuth response omitted access_token" if value.empty?
        raise MalformedResponseError, "nShift OAuth expires_in must be positive" unless expires_in.positive?

        token = Token.new(value:, expires_at: @clock.call + expires_in)
        @cache.write(cache_key, {"value" => value, "expires_at" => token.expires_at.to_f}, expires_in:)
        log("success")
        token
      rescue AuthenticationError => error
        raise TokenError.new(
          "nShift OAuth credentials were rejected",
          provider_request_id: error.provider_request_id,
          provider_code: error.provider_code,
          http_status: error.http_status
        )
      rescue ArgumentError, TypeError
        raise MalformedResponseError, "nShift OAuth response contained an invalid expires_in"
      end

      def cache_key
        @cache_key ||= "solidus_nshift:oauth:#{@cache_namespace}:#{Digest::SHA256.hexdigest(@client_id)}"
      end

      def validate_configuration!
        raise ConfigurationError, "OAuth client_id is required" if @client_id.empty?
        raise ConfigurationError, "OAuth client_secret is required" if @client_secret.empty?
        raise ConfigurationError, "OAuth safety_margin must be non-negative" if @safety_margin.negative?
        raise ConfigurationError, "OAuth attempts must be positive" unless @attempts.positive?
      end

      def log(result)
        @logger&.info(provider: "nshift", operation: "oauth_token", result:)
      end
    end
  end
end
