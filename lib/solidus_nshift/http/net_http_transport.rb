# frozen_string_literal: true

require "net/http"
require "openssl"
require "uri"

module SolidusNshift
  module Http
    class NetHttpTransport
      Response = Data.define(:status, :body, :headers)

      DEFAULT_OPEN_TIMEOUT = 5
      DEFAULT_READ_TIMEOUT = 20
      DEFAULT_WRITE_TIMEOUT = 20
      DEFAULT_MAX_RESPONSE_BYTES = 20 * 1024 * 1024

      def initialize(open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT,
        write_timeout: DEFAULT_WRITE_TIMEOUT, max_response_bytes: DEFAULT_MAX_RESPONSE_BYTES)
        @open_timeout = positive_number!(open_timeout, "open timeout")
        @read_timeout = positive_number!(read_timeout, "read timeout")
        @write_timeout = positive_number!(write_timeout, "write timeout")
        @max_response_bytes = Integer(max_response_bytes)
        raise ConfigurationError, "HTTP response limit must be positive" unless @max_response_bytes.positive?
      rescue ArgumentError, TypeError
        raise ConfigurationError, "nShift HTTP transport settings are invalid"
      end

      def call(method:, url:, headers: {}, body: nil)
        uri = URI.parse(url)
        unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? && uri.fragment.nil?
          raise ConfigurationError, "nShift endpoints must be absolute HTTPS URLs without credentials or fragments"
        end

        request = request_class(method).new(uri.request_uri, headers)
        request.body = body if body
        response = nil
        response_body = +"".b
        connection(uri).request(request) do |streamed_response|
          response = streamed_response
          streamed_response.read_body do |chunk|
            if response_body.bytesize + chunk.bytesize > @max_response_bytes
              raise MalformedResponseError, "nShift response exceeded #{@max_response_bytes} bytes"
            end

            response_body << chunk.b
          end
        end

        Response.new(status: response.code.to_i, body: response_body, headers: response.to_hash)
      rescue URI::InvalidURIError
        raise ConfigurationError, "nShift endpoint URL is invalid"
      end

      private

      def connection(uri)
        Net::HTTP.new(uri.host, uri.port).tap do |http|
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.open_timeout = @open_timeout
          http.read_timeout = @read_timeout
          http.write_timeout = @write_timeout if http.respond_to?(:write_timeout=)
        end
      end

      def request_class(method)
        case method.to_s.downcase
        when "get" then Net::HTTP::Get
        when "post" then Net::HTTP::Post
        when "put" then Net::HTTP::Put
        when "delete" then Net::HTTP::Delete
        else raise ArgumentError, "unsupported HTTP method: #{method}"
        end
      end

      def positive_number!(value, name)
        number = Float(value)
        raise ConfigurationError, "HTTP #{name} must be positive" unless number.finite? && number.positive?

        number
      end
    end
  end
end
