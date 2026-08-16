# frozen_string_literal: true

require "base64"
require "json"
require "uri"

module SolidusNshift
  module Delivery
    class Client
      include Http::ResponseHandling

      BASE_URL = "https://api.unifaun.com/rs-extapi/v1"
      IDENTIFIER = /\A[0-9A-Za-z_.:-]{1,200}\z/

      def initialize(api_key_id:, api_key_secret:, transport: Http::NetHttpTransport.new,
        base_url: BASE_URL, logger: nil)
        @api_key_id = api_key_id.to_s
        @api_key_secret = api_key_secret.to_s
        @transport = transport
        @base_url = base_url.to_s.delete_suffix("/")
        @logger = logger
        validate_configuration!
      end

      def create_shipment(payload:)
        body = request_json(:post, "/shipments?returnFile=false", payload:, mutation: true, allow_array: true)
        value = Array(body).first
        raise MalformedResponseError, "nShift Delivery returned no created shipment" unless value.is_a?(Hash)

        Shipment.from_hash(value)
      end

      def fetch_shipments(fetch_id: "-1")
        body = request_json(:get, "/shipments?#{URI.encode_www_form(fetchId: fetch_id)}")
        shipments = body["shipments"]
        raise MalformedResponseError, "nShift Delivery shipments response omitted shipments" unless shipments.is_a?(Array)

        {
          fetch_id: body["fetchId"].to_s,
          done: body["done"] == true,
          min_delay: body["minDelay"],
          shipments: shipments.map { |value| Shipment.from_hash(value) }
        }
      end

      def find_shipment(reference:, fetch_id: "-1")
        value = reference.to_s
        fetch_shipments(fetch_id:).fetch(:shipments).find do |shipment|
          shipment.reference == value || shipment.order_number == value
        end
      end

      def list_documents(shipment_id:)
        body = request_json(:get, "/shipments/#{identifier!(shipment_id)}/prints", allow_array: true)
        raise MalformedResponseError, "nShift Delivery documents response must be an array" unless body.is_a?(Array)

        body.map { |value| Document.from_hash(value) }
      end

      def download_document(shipment_id:, document_id:, format:)
        expected = (format.to_s.downcase == "pdf") ? "application/pdf" : "application/octet-stream"
        response = with_transport_errors do
          @transport.call(
            method: :get,
            url: "#{@base_url}/shipments/#{identifier!(shipment_id)}/prints/#{identifier!(document_id)}",
            headers: headers.merge("Accept" => expected)
          )
        end
        if response.status >= 400
          body = response.body.empty? ? {} : parse_json(response, allow_array: true)
          raise_for_status!(response, body, error_class: DocumentError)
        end
        content_type = first_header(response.headers, "content-type").to_s.split(";").first
        unless [expected, "application/octet-stream"].include?(content_type)
          raise DocumentError, "nShift Delivery returned an unexpected document content type"
        end
        if expected == "application/pdf" && !response.body.start_with?("%PDF-".b)
          raise DocumentError, "nShift Delivery returned invalid PDF data"
        end

        DocumentContent.new(body: response.body, content_type: expected)
      end

      def cancel_shipment(shipment_id:)
        request_json(:delete, "/shipments/#{identifier!(shipment_id)}", mutation: true, allow_empty: true)
        true
      end

      private

      def request_json(method, path, payload: nil, mutation: false, allow_array: false, allow_empty: false)
        response = with_transport_errors(mutation:) do
          @transport.call(
            method:,
            url: "#{@base_url}#{path}",
            headers: headers,
            body: payload && JSON.generate(payload)
          )
        end
        body = parse_json(response, allow_array:, allow_empty:)
        raise_for_status!(response, body, mutation:)
        log(path, "success", response)
        body
      end

      def headers
        {
          "Accept" => "application/json",
          "Authorization" => "Basic #{Base64.strict_encode64("#{@api_key_id}:#{@api_key_secret}")}",
          "Content-Type" => "application/json",
          "User-Agent" => "SolidusNshift/#{SolidusNshift::VERSION}"
        }
      end

      def identifier!(value)
        normalized = value.to_s
        raise ValidationError, "nShift Delivery identifier has an invalid format" unless IDENTIFIER.match?(normalized)

        normalized
      end

      def validate_configuration!
        raise ConfigurationError, "Delivery API key ID is required" if @api_key_id.empty?
        raise ConfigurationError, "Delivery API key secret is required" if @api_key_secret.empty?
        uri = URI.parse(@base_url)
        raise ConfigurationError, "nShift Delivery base URL must use HTTPS" unless uri.is_a?(URI::HTTPS)
      rescue URI::InvalidURIError
        raise ConfigurationError, "nShift Delivery base URL is invalid"
      end

      def log(path, result, response)
        @logger&.info(
          provider: "nshift",
          api_family: "delivery",
          operation: path.split("?").first,
          result:,
          provider_request_id: request_id(response.headers)
        )
      end
    end
  end
end
