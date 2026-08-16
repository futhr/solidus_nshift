# frozen_string_literal: true

require "unit_helper"

RSpec.describe SolidusNshift::OAuth::TokenProvider do
  let(:now) { Time.utc(2026, 8, 16, 10) }
  let(:clock) { -> { @current_time ||= now } }
  let(:cache) { SolidusNshift::MemoryCache.new(clock:) }
  let(:token_response) { RecordedTransport.json(200, fixture_json("auth/token.json")) }

  def provider(transport:, **options)
    described_class.new(
      client_id: "checkout-client",
      client_secret: "checkout-secret",
      cache:,
      clock:,
      sleeper: ->(_seconds) {},
      transport:,
      **options
    )
  end

  it "caches a token until its safety window" do
    transport = RecordedTransport.new(token_response, token_response)
    instance = provider(transport:)

    expect(instance.token.value).to eq("sanitized-checkout-token")
    expect(instance.token.value).to eq("sanitized-checkout-token")
    expect(transport.requests.length).to eq(1)

    @current_time = now + 3_541
    instance.token
    expect(transport.requests.length).to eq(2)
  end

  it "performs only one acquisition for concurrent callers" do
    transport = RecordedTransport.new do |_request, _number|
      sleep(0.01)
      token_response
    end
    instance = provider(transport:)

    values = 8.times.map { Thread.new { instance.token.value } }.each(&:join).map(&:value)

    expect(values).to all(eq("sanitized-checkout-token"))
    expect(transport.requests.length).to eq(1)
  end

  it "uses bounded backoff for transient failures" do
    waits = []
    transport = RecordedTransport.new(
      RecordedTransport.json(503, fixture_json("errors/provider_error.json")),
      RecordedTransport.json(429, fixture_json("errors/rate_limited.json")),
      token_response
    )
    instance = described_class.new(
      client_id: "checkout-client",
      client_secret: "checkout-secret",
      cache:,
      clock:,
      sleeper: ->(seconds) { waits << seconds },
      transport:
    )

    expect(instance.token.value).to eq("sanitized-checkout-token")
    expect(waits).to eq([0.25, 0.5])
  end

  it "classifies rejected credentials without disclosing them" do
    transport = RecordedTransport.new(RecordedTransport.json(401, fixture_json("auth/invalid_client.json")))

    expect { provider(transport:).token }
      .to raise_error(SolidusNshift::TokenError, /credentials were rejected/) { |error|
        expect(error.message).not_to include("checkout-secret")
      }
  end
end
