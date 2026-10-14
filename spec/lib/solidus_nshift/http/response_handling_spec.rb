# frozen_string_literal: true

require "unit_helper"
require "stringio"

RSpec.describe SolidusNshift::Http::ResponseHandling do
  subject(:handler) do
    Class.new do
      include SolidusNshift::Http::ResponseHandling

      def check(response, mutation: false)
        raise_for_response_status!(response, mutation:)
      end

      def transport(mutation: false, &block)
        with_transport_errors(mutation:, &block)
      end
    end.new
  end

  {
    Net::HTTPBadResponse => "HTTP/1.1 invalid\r\n\r\n",
    Net::HTTPHeaderSyntaxError => "HTTP/1.1 200 OK\r\nContent-Length: invalid\r\n\r\n"
  }.each do |error_class, raw_response|
    it "classifies #{error_class} from a malformed HTTP response" do
      [false, true].each do |mutation|
        outcome = mutation ? SolidusNshift::TimeoutUnknownOutcome : SolidusNshift::TransportError
        expect {
          handler.transport(mutation:) do
            socket = Net::BufferedIO.new(StringIO.new(raw_response))
            Net::HTTPResponse.read_new(socket).content_length
          end
        }.to raise_error(outcome) { |error|
          expect(error.provider_code).to eq(error_class.name)
        }
      end
    end
  end

  it "treats a mutation request timeout response as an unknown outcome" do
    response = RecordedTransport.json(
      408,
      {"message" => "request timed out"},
      headers: {"X-Request-ID" => ["request-1"]}
    )

    expect { handler.check(response, mutation: true) }
      .to raise_error(SolidusNshift::TimeoutUnknownOutcome) { |error|
        expect(error.provider_request_id).to eq("request-1")
      }
  end

  it "handles an unexpected array error body without leaking a parser exception" do
    response = RecordedTransport.json(400, [42])

    expect { handler.check(response) }
      .to raise_error(SolidusNshift::ValidationError, /HTTP 400/)
  end

  it "does not echo provider error bodies that contain customer details" do
    response = RecordedTransport.json(422, {"message" => "Invalid address for private@example.test", "code" => {"email" => "private@example.test"}})

    expect { handler.check(response) }.to raise_error(SolidusNshift::ValidationError) do |error|
      expect(error.message).to eq("nShift request rejected: HTTP 422")
      expect(error.provider_code).to be_nil
    end
  end
end
