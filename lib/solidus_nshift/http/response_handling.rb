# frozen_string_literal: true

require "json"

module SolidusNshift
  module Http
    module ResponseHandling
      private

      def parse_json(response, allow_array: false, allow_empty: false)
        return {} if allow_empty && response.body.empty?
        raise malformed("nShift returned an empty JSON response", response) if response.body.empty?

        parsed = JSON.parse(response.body)
        valid = parsed.is_a?(Hash) || (allow_array && parsed.is_a?(Array))
        raise malformed("nShift response had an unexpected JSON shape", response) unless valid

        parsed
      rescue JSON::ParserError
        raise malformed("nShift response was not valid JSON", response)
      end

      def raise_for_status!(response, body, mutation: false, error_class: Error)
        return if response.status.between?(200, 299)

        klass = case response.status
        when 400, 422 then ValidationError
        when 401, 403 then AuthenticationError
        when 408 then mutation ? TimeoutUnknownOutcome : ProviderUnavailableError
        when 409 then ShipmentConflictError
        when 429 then RateLimitError
        when 500..599 then mutation ? TimeoutUnknownOutcome : ProviderUnavailableError
        else error_class
        end
        raise klass.new(
          provider_error_message(body, response.status),
          provider_request_id: request_id(response.headers),
          provider_code: provider_code(body),
          http_status: response.status,
          retry_after: first_header(response.headers, "retry-after")
        )
      end

      def raise_for_response_status!(response, mutation: false, error_class: Error)
        return if response.status.between?(200, 299)

        body = parse_json(response, allow_array: true, allow_empty: true)
        raise_for_status!(response, body, mutation:, error_class:)
      rescue MalformedResponseError
        raise_for_status!(response, {}, mutation:, error_class:)
      end

      def malformed(message, response)
        MalformedResponseError.new(
          message,
          provider_request_id: request_id(response.headers),
          http_status: response.status
        )
      end

      def provider_error_message(body, status)
        value = if body.is_a?(Hash)
          body["message"] || body["error_description"] || body["error"] || body["errors"]
        elsif body.is_a?(Array) && body.first.is_a?(Hash)
          body.first["message"]
        end
        "nShift request rejected: #{value.is_a?(String) ? value.slice(0, 500) : "HTTP #{status}"}"
      end

      def provider_code(body)
        return body["code"] || body["error"] if body.is_a?(Hash)
        body.first["messageCode"] if body.is_a?(Array) && body.first.is_a?(Hash)
      end

      def request_id(headers)
        %w[x-request-id request-id trace-id correlation-id].filter_map { |name| first_header(headers, name) }.first
      end

      def first_header(headers, name)
        _key, value = headers.find { |key, _value| key.to_s.casecmp?(name) }
        Array(value).first
      end

      def with_transport_errors(mutation: false)
        yield
      rescue Timeout::Error => error
        klass = mutation ? TimeoutUnknownOutcome : TransportError
        raise klass.new("nShift request timed out", provider_code: error.class.name)
      rescue SocketError, IOError, OpenSSL::SSL::SSLError, SystemCallError => error
        klass = mutation ? TimeoutUnknownOutcome : TransportError
        raise klass.new("nShift connection failed", provider_code: error.class.name)
      end
    end
  end
end
