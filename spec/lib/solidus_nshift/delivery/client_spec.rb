# frozen_string_literal: true

require "unit_helper"

RSpec.describe SolidusNshift::Delivery::Client do
  def client(transport)
    described_class.new(api_key_id: "key-id", api_key_secret: "key-secret", transport:)
  end

  it "books a shipment with Basic authentication and normalizes documents" do
    transport = RecordedTransport.new(RecordedTransport.json(201, fixture_json("shipments/booked_single_parcel.json")))

    shipment = client(transport).create_shipment(payload: {shipment: {}})

    expect(shipment.id).to eq("10252317")
    expect(shipment.tracking_number).to eq("4381670977")
    expect(shipment.documents.map(&:id)).to eq(["192364271"])
    expect(transport.requests.first[:headers]["Authorization"])
      .to eq("Basic #{Base64.strict_encode64("key-id:key-secret")}")
  end

  it "preserves every document for a multi-parcel shipment" do
    transport = RecordedTransport.new(RecordedTransport.json(201, fixture_json("shipments/booked_multi_parcel.json")))

    expect(client(transport).create_shipment(payload: {}).documents.map(&:id))
      .to eq(%w[192364272 192364273])
  end

  it "maps provider validation details without echoing request payloads" do
    transport = RecordedTransport.new(RecordedTransport.json(422, fixture_json("shipments/booking_validation_error.json")))

    expect { client(transport).create_shipment(payload: {receiver: {email: "private@example.test"}}) }
      .to raise_error(SolidusNshift::ValidationError, /Not valid postal code/) { |error|
        expect(error.message).not_to include("private@example.test")
      }
  end

  it "does not assume a booking failed after a transport timeout" do
    transport = RecordedTransport.new(Timeout::Error.new("timed out"))

    expect { client(transport).create_shipment(payload: {}) }
      .to raise_error(SolidusNshift::TimeoutUnknownOutcome)
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
