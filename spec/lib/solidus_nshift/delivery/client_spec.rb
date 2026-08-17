# frozen_string_literal: true

require "unit_helper"

RSpec.describe SolidusNshift::Delivery::Client do
  def client(transport)
    described_class.new(api_key_id: "key-id", api_key_secret: "key-secret", transport:)
  end

  def booking_payload(order_number = "solidus-store-h123-1")
    {shipment: {orderNo: order_number}}
  end

  it "books a shipment with Basic authentication and normalizes documents" do
    transport = RecordedTransport.new(RecordedTransport.json(201, fixture_json("shipments/booked_single_parcel.json")))

    shipment = client(transport).create_shipment(payload: booking_payload)

    expect(shipment.id).to eq("10252317")
    expect(shipment.tracking_number).to eq("4381670977")
    expect(shipment.documents.map(&:id)).to eq(["192364271"])
    expect(transport.requests.first[:headers]["Authorization"])
      .to eq("Basic #{Base64.strict_encode64("key-id:key-secret")}")
  end

  it "preserves every document for a multi-parcel shipment" do
    transport = RecordedTransport.new(RecordedTransport.json(201, fixture_json("shipments/booked_multi_parcel.json")))

    expect(client(transport).create_shipment(payload: booking_payload("solidus-store-h124-1")).documents.map(&:id))
      .to eq(%w[192364272 192364273])
  end

  it "rejects undocumented single-object and ambiguous multi-shipment booking responses" do
    value = fixture_json("shipments/booked_single_parcel.json").first
    single_transport = RecordedTransport.new(RecordedTransport.json(201, value))
    multiple_transport = RecordedTransport.new(RecordedTransport.json(201, [value, value.merge("id" => "other")]))

    expect { client(single_transport).create_shipment(payload: booking_payload) }
      .to raise_error(SolidusNshift::MalformedResponseError, /exactly one/)
    expect { client(multiple_transport).create_shipment(payload: booking_payload) }
      .to raise_error(SolidusNshift::MalformedResponseError, /exactly one/)
  end

  it "rejects malformed shipment and document container shapes" do
    shipment = fixture_json("shipments/booked_single_parcel.json").first

    expect { SolidusNshift::Delivery::Shipment.from_hash(shipment.merge("parcels" => {})) }
      .to raise_error(SolidusNshift::MalformedResponseError, /parcels must be an array/)
    expect { SolidusNshift::Delivery::Shipment.from_hash(shipment.merge("prints" => [nil])) }
      .to raise_error(SolidusNshift::MalformedResponseError, /prints must be an array/)
    expect { SolidusNshift::Delivery::Document.from_hash({"id" => nil, "type" => "PDF"}) }
      .to raise_error(SolidusNshift::MalformedResponseError, /omitted id/)
  end

  it "maps provider validation details without echoing request payloads" do
    transport = RecordedTransport.new(RecordedTransport.json(422, fixture_json("shipments/booking_validation_error.json")))

    payload = booking_payload.merge(receiver: {email: "private@example.test"})
    expect { client(transport).create_shipment(payload:) }
      .to raise_error(SolidusNshift::ValidationError, /Not valid postal code/) { |error|
        expect(error.message).not_to include("private@example.test")
      }
  end

  it "does not assume a booking failed after a transport timeout" do
    transport = RecordedTransport.new(Timeout::Error.new("timed out"))

    expect { client(transport).create_shipment(payload: booking_payload) }
      .to raise_error(SolidusNshift::TimeoutUnknownOutcome)
  end

  it "classifies a non-JSON provider outage as an unknown mutation outcome" do
    transport = RecordedTransport.new(RecordedTransport.binary(503, "<html>unavailable</html>", content_type: "text/html"))

    expect { client(transport).create_shipment(payload: booking_payload) }
      .to raise_error(SolidusNshift::TimeoutUnknownOutcome) { |error| expect(error.http_status).to eq(503) }
  end

  it "rejects a booking response for a different order number" do
    value = fixture_json("shipments/booked_single_parcel.json").first.merge("orderNo" => "another-order")
    transport = RecordedTransport.new(RecordedTransport.json(201, [value]))

    expect { client(transport).create_shipment(payload: booking_payload) }
      .to raise_error(SolidusNshift::MalformedResponseError, /different order number/)
  end

  it "requires explicit non-return and non-consolidated shipment flags" do
    value = fixture_json("shipments/booked_single_parcel.json").first.except("consolidated")
    transport = RecordedTransport.new(RecordedTransport.json(201, [value]))

    expect { client(transport).create_shipment(payload: booking_payload) }
      .to raise_error(SolidusNshift::MalformedResponseError, /unsupported return or consolidated/)
  end

  it "rejects unsafe document identifiers and unsupported formats" do
    value = fixture_json("shipments/booked_single_parcel.json").first
    unsafe_id = value.merge("prints" => [value.fetch("prints").first.merge("id" => "../label")])
    unsupported = value.merge("prints" => [value.fetch("prints").first.merge("type" => "epl")])

    [unsafe_id, unsupported].each do |response|
      transport = RecordedTransport.new(RecordedTransport.json(201, [response]))
      expect { client(transport).create_shipment(payload: booking_payload) }
        .to raise_error(SolidusNshift::MalformedResponseError)
    end
  end

  it "reconciles by exact order number through shipment history" do
    value = fixture_json("shipments/booked_single_parcel.json").first
    transport = RecordedTransport.new(
      RecordedTransport.json(200, {"page" => 0, "totalPages" => 1, "shipments" => [value]})
    )

    shipment = client(transport).find_shipment(reference: value.fetch("orderNo"))

    expect(shipment.id).to eq("10252317")
    expect(transport.requests.first[:url]).to include(
      "/shipments-history?", "searchField=orderNo", "searchValue=solidus-store-h123-1"
    )
    expect(transport.requests.first[:url]).not_to include("fetchId")
  end

  it "refuses to adopt ambiguous duplicate history results" do
    value = fixture_json("shipments/booked_single_parcel.json").first
    duplicate = value.merge("id" => "10252319")
    transport = RecordedTransport.new(
      RecordedTransport.json(200, {"page" => 0, "totalPages" => 1, "shipments" => [value, duplicate]})
    )

    expect { client(transport).find_shipment(reference: value.fetch("orderNo")) }
      .to raise_error(SolidusNshift::ShipmentConflictError, /multiple shipments/)
  end

  it "downloads and validates binary PDF labels" do
    data = "%PDF-1.7\nsynthetic".b
    transport = RecordedTransport.new(RecordedTransport.binary(200, data, content_type: "application/pdf"))

    document = client(transport).download_document(shipment_id: "10252317", document_id: "192364271", format: "pdf")

    expect(document.body).to eq(data)
    expect(document.content_type).to eq("application/pdf")
  end

  it "rejects HTML masquerading as a PDF" do
    transport = RecordedTransport.new(RecordedTransport.binary(200, "<html>error</html>", content_type: "text/html"))

    expect { client(transport).download_document(shipment_id: "1", document_id: "2", format: "pdf") }
      .to raise_error(SolidusNshift::DocumentError)
  end
end
