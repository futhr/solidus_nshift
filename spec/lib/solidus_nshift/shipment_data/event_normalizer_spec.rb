# frozen_string_literal: true

require "unit_helper"

RSpec.describe SolidusNshift::ShipmentData::EventNormalizer do
  it "normalizes known events with timezone-aware timestamps" do
    value = fixture_json("tracking/in_transit.json").fetch("events").first

    event = described_class.new.call(value)

    expect(event.status).to eq("in_transit")
    expect(event.occurred_at.utc_offset).to eq(7200)
    expect(event).not_to be_terminal
  end

  it "retains unknown future status codes safely" do
    value = fixture_json("tracking/unknown_future_status.json").fetch("events").first

    event = described_class.new.call(value)

    expect(event.status).to eq("unknown")
    expect(event.raw_code).to eq("QUANTUM_HANDOFF")
  end

  it "rejects malformed timestamps rather than silently coercing them" do
    expect { described_class.new.call("eventCode" => "DELIVERED", "eventTime" => "not-a-time") }
      .to raise_error(SolidusNshift::MalformedResponseError)
  end
end
