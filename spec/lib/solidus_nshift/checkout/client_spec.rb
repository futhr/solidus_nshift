# frozen_string_literal: true

require "unit_helper"

module CheckoutClientSpec
  TokenProvider = Struct.new(:value, :invalidations) do
    def token
      SolidusNshift::OAuth::Token.new(value:, expires_at: Time.now + 3600)
    end

    def invalidate!
      self.invalidations += 1
    end
  end
end

RSpec.describe SolidusNshift::Checkout::Client do
  let(:tokens) { CheckoutClientSpec::TokenProvider.new(value: "token", invalidations: 0) }

  it "creates a four-hour checkout session" do
    transport = RecordedTransport.new(RecordedTransport.json(201, fixture_json("checkout/session.json")))
    client = described_class.new(token_provider: tokens, transport:, clock: -> { Time.utc(2026, 8, 16, 10) })

    session = client.create_session(connection_id: "connection-1", attributes: {})

    expect(session.id).to eq("session-2026-0001")
    expect(session.expires_at).to eq(Time.utc(2026, 8, 16, 14))
    expect(transport.requests.first[:url]).to end_with("/options/v1/sessions/connection-1")
    expect(JSON.parse(transport.requests.first[:body])).to eq({})
  end

  it "normalizes and deterministically deduplicates home delivery options" do
    transport = RecordedTransport.new(RecordedTransport.json(200, fixture_json("checkout/shipping_options_home.json")))
    client = described_class.new(token_provider: tokens, transport:)

    options = client.shipping_options(session_id: "session-1", payload: {receiver: {}}, currency: "SEK")

    expect(options.length).to eq(1)
    expect(options.first.external_id).to eq("home-standard")
    expect(options.first.price).to eq(BigDecimal("89.5"))
    expect(options.first.service_code).to eq("P19")
  end

  it "normalizes pickup point identity separately from display data" do
    transport = RecordedTransport.new(RecordedTransport.json(200, fixture_json("checkout/shipping_options_pickup.json")))
    option = described_class.new(token_provider: tokens, transport:)
      .shipping_options(session_id: "session-1", payload: {}, currency: "SEK").first

    expect(option).to be_pickup
    expect(option.pickup_points.first.id).to eq("SE-10001")
    expect(option.pickup_points.first.to_h).to include(name: "Synthetic Market", country_code: "SE")
  end

  it "distinguishes a valid no-options response from provider failure" do
    transport = RecordedTransport.new(RecordedTransport.json(200, fixture_json("checkout/no_options.json")))
    client = described_class.new(token_provider: tokens, transport:)

    expect(client.shipping_options(session_id: "session-1", payload: {}, currency: "SEK")).to eq([])
  end

  it "invalidates once and retries after an unauthorized response" do
    transport = RecordedTransport.new(
      RecordedTransport.json(401, fixture_json("errors/unauthorized.json")),
      RecordedTransport.json(200, fixture_json("checkout/no_options.json"))
    )
    client = described_class.new(token_provider: tokens, transport:)

    client.shipping_options(session_id: "session-1", payload: {}, currency: "SEK")

    expect(tokens.invalidations).to eq(1)
    expect(transport.requests.length).to eq(2)
  end

  it "maps an expired session to a stale-session error" do
    transport = RecordedTransport.new(RecordedTransport.json(422, fixture_json("checkout/stale_session.json")))
    client = described_class.new(token_provider: tokens, transport:)

    expect { client.shipping_options(session_id: "session-1", payload: {}, currency: "SEK") }
      .to raise_error(SolidusNshift::StaleSessionError)
  end

  it "treats partial-shipment timeout as an unknown mutation outcome" do
    transport = RecordedTransport.new(Timeout::Error.new("timed out"))
    client = described_class.new(token_provider: tokens, transport:)

    expect { client.create_partial_shipment(payload: {orderId: "order-1"}) }
      .to raise_error(SolidusNshift::TimeoutUnknownOutcome)
  end
end
