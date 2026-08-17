# frozen_string_literal: true

require "unit_helper"

RSpec.describe SolidusNshift::Http::ResponseHandling do
  subject(:handler) do
    Class.new do
      include SolidusNshift::Http::ResponseHandling

      def check(response, mutation: false)
        raise_for_response_status!(response, mutation:)
      end
    end.new
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
end
