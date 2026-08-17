# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::ReconcileBooking do
  let(:data) { create_nshift_shipment }
  let(:checkout_client) { instance_double(SolidusNshift::Checkout::Client) }
  let(:delivery_client) { instance_double(SolidusNshift::Delivery::Client) }
  let(:provider_shipment) do
    SolidusNshift::Delivery::Shipment.from_hash(nshift_fixture_json("shipments/booked_single_parcel.json").first)
  end

  before do
    allow(checkout_client).to receive(:create_partial_shipment).and_return({"id" => "partial-1"})
    allow(delivery_client).to receive(:create_shipment)
      .and_raise(SolidusNshift::TimeoutUnknownOutcome, "unknown result")
    allow(delivery_client).to receive(:find_shipment).and_return(nil)
    allow(data[:connection]).to receive(:checkout_client).and_return(checkout_client)
    allow(data[:connection]).to receive(:delivery_client).and_return(delivery_client)
  end

  it "adopts a found Delivery shipment without creating another one" do
    fulfillment = SolidusNshift::BookingService.new(shipment: data[:shipment]).call
    allow(delivery_client).to receive(:find_shipment)
      .with(reference: fulfillment.merchant_reference).and_return(provider_shipment)

    described_class.new(fulfillment:).call

    expect(fulfillment.reload.state).to eq("booked")
    expect(fulfillment.provider_shipment_id).to eq("10252317")
    expect(fulfillment.operations.find_by(kind: "delivery_booking")).to have_attributes(
      status: "succeeded", provider_resource_id: "10252317"
    )
    expect(delivery_client).to have_received(:create_shipment).once
  end

  it "remains reconciliation-pending when the provider lookup finds nothing" do
    fulfillment = SolidusNshift::BookingService.new(shipment: data[:shipment]).call
    allow(delivery_client).to receive(:find_shipment).and_return(nil)

    described_class.new(fulfillment:).call

    expect(fulfillment.reload.state).to eq("reconciliation_pending")
    expect(fulfillment.last_reconciled_at).to be_present
    expect(delivery_client).to have_received(:create_shipment).once
  end

  it "does not guess after an unresolved Checkout mutation" do
    allow(checkout_client).to receive(:create_partial_shipment)
      .and_raise(SolidusNshift::TimeoutUnknownOutcome, "unknown result")
    fulfillment = SolidusNshift::BookingService.new(shipment: data[:shipment]).call

    described_class.new(fulfillment:).call

    expect(fulfillment.reload.state).to eq("reconciliation_pending")
    expect(fulfillment.last_error_message).to match(/manual provider verification/)
    expect(delivery_client).not_to have_received(:find_shipment)
  end

  it "confirms an ambiguous cancellation from Shipment History" do
    fulfillment = SolidusNshift::Fulfillment.create!(
      shipment: data[:shipment], connection: data[:connection], rate_selection: data[:selection],
      merchant_reference: SolidusNshift::Reference.for(data[:shipment]), state: "reconciliation_pending",
      provider_shipment_id: "10252317"
    )
    operation = fulfillment.operations.create!(
      kind: "delivery_cancel", status: "unknown", request_fingerprint: "a" * 64
    )
    value = nshift_fixture_json("shipments/booked_single_parcel.json").first.merge("status" => "CANCELED")
    canceled_shipment = SolidusNshift::Delivery::Shipment.from_hash(value)
    allow(delivery_client).to receive(:find_shipment).and_return(canceled_shipment)

    described_class.new(fulfillment:).call

    expect(fulfillment.reload).to have_attributes(state: "canceled", provider_status: "CANCELED")
    expect(operation.reload).to have_attributes(status: "succeeded", provider_resource_id: "10252317")
  end
end
