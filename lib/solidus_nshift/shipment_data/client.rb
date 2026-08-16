# frozen_string_literal: true

require "json"
require "uri"

module SolidusNshift
  module ShipmentData
    class Client
      include Http::ResponseHandling

      BASE_URL = "https://api.nshiftportal.com/track/shipmentdata"
      IDENTIFIER = /\A[0-9A-Za-z_.:-]{1,200}\z/

      def initialize(token_provider:, transport: Http::NetHttpTransport.new, base_url: BASE_URL, logger: nil)
        @token_provider = token_provider
        @transport = transport
        @base_url = base_url.to_s.delete_suffix("/")
        @logger = logger
        validate_base_url!
      end

      def find_by_order_number(order_number:, start_time:, end_time:)
        request_json(
          :post,
          "/Operational/Shipments/ByOrderNumber",
          payload: {
            query: order_number.to_s,
            startDate: start_time.iso8601,
            endDate: end_time.iso8601,
            pageSize: 20,
            pageIndex: 0,
            installationTags: [],
            actorTags: [],
            carrierTags: []
          }
        )
      end

      def events(shipment_uuid:)
        body = request_json(:get, "/#{identifier!(shipment_uuid)}/events/valid")
        values = body.is_a?(Array) ? body : body["events"] || body["items"] || []
        raise MalformedResponseError, "nShift Shipment Data events must be an array" unless values.is_a?(Array)

        values.map { |value| EventNormalizer.new.call(value) }
      end

      private

      def request_json(method, path, payload: nil, retried: false)
        token = @token_provider.token
        response = with_transport_errors do
          @transport.call(
            method:,
            url: "#{@base_url}#{path}",
            headers: {
              "Accept" => "application/json",
              "Authorization" => "Bearer #{token.value}",
              "Content-Type" => "application/json",
              "User-Agent" => "SolidusNshift/#{SolidusNshift::VERSION}"
            },
            body: payload && JSON.generate(payload)
          )
        end
        body = parse_json(response, allow_array: true)
        if response.status == 401 && !retried
          @token_provider.invalidate!
          return request_json(method, path, payload:, retried: true)
        end
        raise_for_status!(response, body, error_class: TrackingError)
        log(path, response)
        body
      end

      def identifier!(value)
        normalized = value.to_s
        raise ValidationError, "Shipment Data identifier has an invalid format" unless IDENTIFIER.match?(normalized)

        normalized
      end

      def validate_base_url!
        uri = URI.parse(@base_url)
        raise ConfigurationError, "nShift Shipment Data base URL must use HTTPS" unless uri.is_a?(URI::HTTPS)
      rescue URI::InvalidURIError
        raise ConfigurationError, "nShift Shipment Data base URL is invalid"
      end

      def log(path, response)
        @logger&.info(
          provider: "nshift",
          api_family: "shipment_data",
          operation: path,
          result: "success",
          provider_request_id: request_id(response.headers)
        )
      end
    end
  end
end
