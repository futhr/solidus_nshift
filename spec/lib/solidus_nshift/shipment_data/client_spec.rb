# frozen_string_literal: true

require "unit_helper"

module ShipmentDataClientSpec
  TokenProvider = Struct.new(:invalidations) do
    def token
      SolidusNshift::OAuth::Token.new(value: "tracking-token", expires_at: Time.now + 3600)
    end

    def invalidate!
      self.invalidations += 1
    end
  end
end

RSpec.describe SolidusNshift::ShipmentData::Client do
  let(:tokens) { ShipmentDataClientSpec::TokenProvider.new(0) }

  def client(transport)
    described_class.new(token_provider: tokens, transport:)
  end

  it "searches the documented order-number endpoint with a bounded date range" do
    result = fixture_json("tracking/search_result.json")
    transport = RecordedTransport.new(RecordedTransport.json(200, result))
    start_time = Time.iso8601("2026-08-01T00:00:00Z")
    end_time = Time.iso8601("2026-08-02T00:00:00Z")

    expect(client(transport).find_by_order_number(order_number: "order-1", start_time:, end_time:)).to eq(result)
    request = transport.requests.first
    expect(request[:url]).to end_with("/Operational/Shipments/ByOrderNumber")
    expect(JSON.parse(request[:body])).to include("query" => "order-1", "pageSize" => 20, "pageIndex" => 0)
  end

  it "follows full pages with a hard pagination bound" do
    full_page = 20.times.map { |index| {"uuid" => "uuid-#{index}", "orderNumber" => "order-1"} }
    final_page = [{"uuid" => "uuid-final", "orderNumber" => "order-1"}]
    transport = RecordedTransport.new(
      RecordedTransport.json(200, full_page),
      RecordedTransport.json(200, final_page)
    )

    values = client(transport).find_by_order_number(
      order_number: "order-1",
      start_time: Time.iso8601("2026-08-01T00:00:00Z"),
      end_time: Time.iso8601("2026-08-02T00:00:00Z")
    )

    expect(values.length).to eq(21)
    expect(JSON.parse(transport.requests.last[:body])).to include("pageIndex" => 1)
  end

  it "fails closed instead of silently truncating a full final page" do
    full_page = 20.times.map { |index| {"uuid" => "uuid-#{index}", "orderNumber" => "order-1"} }
    transport = RecordedTransport.new(
      *SolidusNshift::ShipmentData::Client::MAX_PAGES.times.map { RecordedTransport.json(200, full_page) }
    )

    expect do
      client(transport).find_by_order_number(
        order_number: "order-1",
        start_time: Time.iso8601("2026-08-01T00:00:00Z"),
        end_time: Time.iso8601("2026-08-02T00:00:00Z")
      )
    end.to raise_error(SolidusNshift::MalformedResponseError, /page limit/)
  end

  it "reads shipment and package tracking events from shipment information" do
    body = {
      "events" => [fixture_json("tracking/in_transit.json").fetch("events").first],
      "lines" => [{"packages" => [{"events" => [fixture_json("tracking/delivered.json").fetch("events").first]}]}]
    }
    transport = RecordedTransport.new(RecordedTransport.json(200, body))

    events = client(transport).events(shipment_uuid: "shipment-uuid-1")

    expect(events.map(&:status)).to eq(%w[in_transit delivered])
    expect(transport.requests.first[:url]).to end_with("/Operational/Shipments/shipment-uuid-1")
    expect(transport.requests.first[:url]).not_to include("events/valid")
  end

  it "retries unauthorized non-JSON responses once" do
    transport = RecordedTransport.new(
      RecordedTransport.binary(401, "unauthorized", content_type: "text/plain"),
      RecordedTransport.json(200, {"events" => [], "lines" => []})
    )

    expect(client(transport).events(shipment_uuid: "shipment-1")).to eq([])
    expect(tokens.invalidations).to eq(1)
  end

  it "rejects invalid search ranges before sending a request" do
    transport = RecordedTransport.new
    now = Time.iso8601("2026-08-16T00:00:00Z")

    expect { client(transport).find_by_order_number(order_number: "", start_time: now, end_time: now + 1) }
      .to raise_error(SolidusNshift::ValidationError)
    expect { client(transport).find_by_order_number(order_number: "order-1", start_time: now, end_time: now + 32 * 86_400) }
      .to raise_error(SolidusNshift::ValidationError)
    expect(transport.requests).to be_empty
  end
end
