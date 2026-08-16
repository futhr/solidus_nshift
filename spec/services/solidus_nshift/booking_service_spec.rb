# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::BookingService do
  let(:data) { create_nshift_shipment(pickup: true) }
  let(:connection) { data[:connection] }
  let(:checkout_client) { instance_double(SolidusNshift::Checkout::Client) }
  let(:delivery_client) { instance_double(SolidusNshift::Delivery::Client) }
  let(:provider_shipment) do
    SolidusNshift::Delivery::Shipment.from_hash(nshift_fixture_json("shipments/booked_single_parcel.json").first)
  end

  before do
    allow(checkout_client).to receive(:create_partial_shipment).and_return({"id" => "partial-1"})
    allow(delivery_client).to receive(:create_shipment).and_return(provider_shipment)
    allow(connection).to receive(:checkout_client).and_return(checkout_client)
    allow(connection).to receive(:delivery_client).and_return(delivery_client)
  end

  it "creates one effective provider shipment and persists normalized output" do
    2.times { described_class.new(shipment: data[:shipment]).call }

    fulfillment = data[:shipment].reload.nshift_fulfillment
    expect(fulfillment).to have_attributes(
      state: "booked",
      checkout_partial_shipment_id: "partial-1",
      provider_shipment_id: "10252317",
      tracking_number: "4381670977"
    )
    expect(fulfillment.operations.order(:kind).pluck(:kind, :status)).to contain_exactly(
      ["checkout_partial", "succeeded"], ["delivery_booking", "succeeded"]
    )
    expect(fulfillment.documents.pluck(:provider_document_id, :format)).to eq([["192364271", "pdf"]])
    expect(data[:shipment].reload.tracking).to eq("4381670977")
    expect(checkout_client).to have_received(:create_partial_shipment).once
    expect(delivery_client).to have_received(:create_shipment).once
  end

  it "uses stable references and the selected option in both provider payloads" do
    checkout_payload = nil
    delivery_payload = nil
    allow(checkout_client).to receive(:create_partial_shipment) do |payload:|
      checkout_payload = payload
      {"id" => "partial-1"}
    end
    allow(delivery_client).to receive(:create_shipment) do |payload:|
      delivery_payload = payload
      provider_shipment
    end

    fulfillment = described_class.new(shipment: data[:shipment]).call

    expect(checkout_payload).to include(
      sessionId: "session-1", shippingOptionId: "pickup-option", orderId: fulfillment.merchant_reference
    )
    expect(checkout_payload[:pickupPoint]).to eq(id: "SE-10001")
    expect(delivery_payload).to include(orderNo: fulfillment.merchant_reference)
    expect(delivery_payload[:agent]).to include(quickId: "SE-10001")
  end

  it "stops safely and schedules reconciliation after an ambiguous Delivery timeout" do
    allow(delivery_client).to receive(:create_shipment)
      .and_raise(SolidusNshift::TimeoutUnknownOutcome, "timed out after dispatch")

    expect { described_class.new(shipment: data[:shipment]).call }
      .to have_enqueued_job(SolidusNshift::ReconcileBookingJob)

    fulfillment = data[:shipment].reload.nshift_fulfillment
    expect(fulfillment.state).to eq("reconciliation_pending")
    expect(fulfillment.operations.find_by(kind: "delivery_booking").status).to eq("unknown")

    described_class.new(shipment: data[:shipment]).call
    expect(delivery_client).to have_received(:create_shipment).once
  end

  it "never proceeds to Delivery if the Checkout mutation has an unknown outcome" do
    allow(checkout_client).to receive(:create_partial_shipment)
      .and_raise(SolidusNshift::TimeoutUnknownOutcome, "timed out")

    fulfillment = described_class.new(shipment: data[:shipment]).call

    expect(fulfillment.state).to eq("reconciliation_pending")
    expect(fulfillment.operations.pluck(:kind, :status)).to eq([["checkout_partial", "unknown"]])
    expect(delivery_client).not_to have_received(:create_shipment)
  end

  it "records a definitive provider rejection and permits a safe corrected retry" do
    allow(checkout_client).to receive(:create_partial_shipment)
      .and_raise(SolidusNshift::ValidationError.new("invalid receiver", provider_code: "ZIP"))

    fulfillment = described_class.new(shipment: data[:shipment]).call

    expect(fulfillment.state).to eq("rejected")
    expect(fulfillment.last_error_code).to eq("ZIP")
    expect(fulfillment.operations.first.status).to eq("rejected")
    expect(delivery_client).not_to have_received(:create_shipment)
  end

  it "rejects stale selection context before any provider mutation" do
    data[:order].update!(ship_address: create(:address, country_iso_code: "SE", zipcode: "411 01"))

    expect { described_class.new(shipment: data[:shipment]).call }
      .to raise_error(SolidusNshift::StaleSessionError)
    expect(checkout_client).not_to have_received(:create_partial_shipment)
  end
end
