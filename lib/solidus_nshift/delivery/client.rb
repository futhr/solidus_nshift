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
      MAX_HISTORY_PAGES = 10
      DOCUMENT_FORMATS = %w[pdf zpl].freeze

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
        expected_order_number = order_number!(payload)
        body = request_json(:post, "/shipments?returnFile=false", payload:, mutation: true, allow_array: true)
        unless body.is_a?(Array) && body.one? && body.first.is_a?(Hash)
          raise MalformedResponseError, "nShift Delivery must return exactly one created shipment"
        end

        shipment = validate_supported_shipment!(Shipment.from_hash(body.first))
        unless shipment.order_number == expected_order_number
          raise MalformedResponseError, "nShift Delivery returned a shipment for a different order number"
        end

        shipment
      end

      def find_shipment(reference:)
        value = reference.to_s
        raise ValidationError, "nShift Delivery reference is required" if value.empty?

        matches = history_pages(value).flat_map do |body|
          body.fetch("shipments").filter_map do |shipment|
            unless shipment.is_a?(Hash)
              raise MalformedResponseError, "nShift Delivery shipment history entry must be an object"
            end
            next unless shipment["orderNo"].to_s == value

            validate_supported_shipment!(Shipment.from_hash(shipment))
          end
        end.uniq(&:id)
        if matches.length > 1
          raise ShipmentConflictError, "nShift Delivery found multiple shipments for the merchant reference"
        end

        matches.first
      end

      def list_documents(shipment_id:)
        body = request_json(:get, "/shipments/#{identifier!(shipment_id)}/prints", allow_array: true)
        raise MalformedResponseError, "nShift Delivery documents response must be an array" unless body.is_a?(Array)

        body.map { |value| validate_document!(Document.from_hash(value)) }
      end

      def download_document(shipment_id:, document_id:, format:)
        normalized_format = format.to_s.downcase
        unless DOCUMENT_FORMATS.include?(normalized_format)
          raise ValidationError, "nShift Delivery document format is unsupported"
        end

        expected = (normalized_format == "pdf") ? "application/pdf" : "application/octet-stream"
        response = with_transport_errors do
          @transport.call(
            method: :get,
            url: "#{@base_url}/shipments/#{identifier!(shipment_id)}/prints/#{identifier!(document_id)}",
            headers: headers.merge("Accept" => expected)
          )
        end
        raise_for_response_status!(response, error_class: DocumentError)
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

      def history_pages(reference)
        pages = []
        total_pages = 1
        page = 0
        while page < total_pages
          if page >= MAX_HISTORY_PAGES
            raise MalformedResponseError, "nShift Delivery shipment history exceeded the page limit"
          end

          query = URI.encode_www_form(page:, searchField: "orderNo", searchValue: reference)
          body = request_json(:get, "/shipments-history?#{query}")
          shipments = body["shipments"]
          raise MalformedResponseError, "nShift Delivery shipment history omitted shipments" unless shipments.is_a?(Array)

          total_pages = Integer(body.fetch("totalPages"))
          unless total_pages.between?(0, MAX_HISTORY_PAGES)
            raise MalformedResponseError, "nShift Delivery shipment history exceeded the page limit"
          end

          pages << body
          page += 1
        end
        pages
      rescue ArgumentError, TypeError, KeyError
        raise MalformedResponseError, "nShift Delivery shipment history had invalid pagination"
      end

      def request_json(method, path, payload: nil, mutation: false, allow_array: false, allow_empty: false)
        response = with_transport_errors(mutation:) do
          @transport.call(
            method:,
            url: "#{@base_url}#{path}",
            headers: headers,
            body: payload && JSON.generate(payload)
          )
        end
        raise_for_response_status!(response, mutation:)
        body = parse_json(response, allow_array:, allow_empty:)
        log(path, "success", response)
        body
      end

      def validate_supported_shipment!(shipment)
        unless IDENTIFIER.match?(shipment.id)
          raise MalformedResponseError, "nShift Delivery returned an invalid shipment identifier"
        end
        unless shipment.return_shipment == false && shipment.consolidated == false
          raise MalformedResponseError, "nShift Delivery returned an unsupported return or consolidated shipment"
        end
        shipment.documents.each { |document| validate_document!(document) }

        shipment
      end

      def validate_document!(document)
        unless IDENTIFIER.match?(document.id)
          raise MalformedResponseError, "nShift Delivery returned an invalid document identifier"
        end
        unless DOCUMENT_FORMATS.include?(document.format)
          raise MalformedResponseError, "nShift Delivery returned an unsupported document format"
        end

        document
      end

      def order_number!(payload)
        shipment = payload[:shipment] || payload["shipment"] if payload.is_a?(Hash)
        value = shipment[:orderNo] || shipment["orderNo"] if shipment.is_a?(Hash)
        normalized = value.to_s
        raise ValidationError, "nShift Delivery order number is required" if normalized.empty?

        normalized
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
        valid = uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
        raise ConfigurationError, "nShift Delivery base URL must be an absolute HTTPS URL" unless valid
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
