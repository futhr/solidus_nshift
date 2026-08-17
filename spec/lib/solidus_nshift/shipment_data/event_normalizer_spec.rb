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
    expect(event.raw_code).to eq("9001")
  end

  it "rejects malformed timestamps rather than silently coercing them" do
    expect do
      described_class.new.call(
        "uuid" => "event-1", "normalizedStatusId" => 3000,
        "normalizedStatusName" => "Delivered", "date" => "not-a-time"
      )
    end
      .to raise_error(SolidusNshift::MalformedResponseError)
  end

  it "maps normalized status ID families without guessing carrier labels" do
    values = {
      1000 => "created",
      2001 => "out_for_delivery",
      2003 => "in_transit",
      3000 => "delivered",
      5002 => "exception",
      6004 => "canceled"
    }

    values.each do |status_id, expected|
      event = described_class.new.call(
        "uuid" => "event-#{status_id}", "normalizedStatusId" => status_id,
        "normalizedStatusName" => expected, "date" => "2026-08-16T10:00:00Z"
      )
      expect(event.status).to eq(expected)
    end
  end

  it "requires the documented event identity and normalized status" do
    base = {"normalizedStatusId" => 2000, "normalizedStatusName" => "In Transit", "date" => "2026-08-16T10:00:00Z"}
    expect { described_class.new.call(base) }.to raise_error(SolidusNshift::MalformedResponseError, /UUID/)
    expect { described_class.new.call(base.merge("uuid" => "event-1", "normalizedStatusName" => nil)) }
      .to raise_error(SolidusNshift::MalformedResponseError, /normalized status/)
  end
end
