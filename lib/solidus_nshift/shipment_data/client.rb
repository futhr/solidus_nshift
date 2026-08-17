# frozen_string_literal: true

require "json"
require "uri"

module SolidusNshift
  module ShipmentData
    class Client
      include Http::ResponseHandling

      BASE_URL = "https://api.nshiftportal.com/track/shipmentdata"
      IDENTIFIER = /\A[0-9A-Za-z_.:-]{1,200}\z/
      PAGE_SIZE = 20
      MAX_PAGES = 5

      def initialize(token_provider:, transport: Http::NetHttpTransport.new, base_url: BASE_URL, logger: nil)
        @token_provider = token_provider
        @transport = transport
        @base_url = base_url.to_s.delete_suffix("/")
        @logger = logger
        validate_base_url!
      end

      def find_by_order_number(order_number:, start_time:, end_time:)
        query = order_number.to_s
        validate_search!(query, start_time, end_time)
        shipments = []
        MAX_PAGES.times do |page_index|
          page = request_json(
            :post,
            "/Operational/Shipments/ByOrderNumber",
            payload: search_payload(query, start_time, end_time, page_index)
          )
          raise MalformedResponseError, "nShift Shipment Data search must be an array" unless page.is_a?(Array)

          shipments.concat(page)
          return shipments if page.length < PAGE_SIZE
        end
        raise MalformedResponseError, "nShift Shipment Data search exceeded the page limit"
      end

      def events(shipment_uuid:)
        body = request_json(:get, "/Operational/Shipments/#{identifier!(shipment_uuid)}")
        raise MalformedResponseError, "nShift Shipment Data shipment must be an object" unless body.is_a?(Hash)

        event_values(body).map { |value| EventNormalizer.new.call(value) }
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
        if response.status == 401 && !retried
          @token_provider.invalidate!
          return request_json(method, path, payload:, retried: true)
        end
        raise_for_response_status!(response, error_class: TrackingError)
        body = parse_json(response, allow_array: true)
        log(path, response)
        body
      end

      def identifier!(value)
        normalized = value.to_s
        raise ValidationError, "Shipment Data identifier has an invalid format" unless IDENTIFIER.match?(normalized)

        normalized
      end

      def search_payload(query, start_time, end_time, page_index)
        {
          query:,
          startDate: start_time.iso8601,
          endDate: end_time.iso8601,
          pageSize: PAGE_SIZE,
          pageIndex: page_index,
          installationTags: [],
          actorTags: [],
          carrierTags: []
        }
      end

      def validate_search!(query, start_time, end_time)
        raise ValidationError, "Shipment Data order number is required" if query.empty?
        raise ValidationError, "Shipment Data search range is invalid" unless start_time < end_time
        if end_time - start_time > 31 * 24 * 60 * 60
          raise ValidationError, "Shipment Data search range cannot exceed 31 days"
        end
      rescue NoMethodError, TypeError
        raise ValidationError, "Shipment Data search range is invalid"
      end

      def event_values(shipment)
        shipment_events = array_field(shipment, "events")
        package_events = array_field(shipment, "lines").flat_map do |line|
          raise MalformedResponseError, "nShift Shipment Data line must be an object" unless line.is_a?(Hash)

          array_field(line, "packages").flat_map do |package|
            raise MalformedResponseError, "nShift Shipment Data package must be an object" unless package.is_a?(Hash)

            array_field(package, "events")
          end
        end
        shipment_events + package_events
      end

      def array_field(value, name)
        field = value.fetch(name, [])
        raise MalformedResponseError, "nShift Shipment Data #{name} must be an array" unless field.is_a?(Array)

        field
      end

      def validate_base_url!
        uri = URI.parse(@base_url)
        valid = uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
        raise ConfigurationError, "nShift Shipment Data base URL must be an absolute HTTPS URL" unless valid
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
