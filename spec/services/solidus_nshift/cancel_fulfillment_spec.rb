# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::CancelFulfillment do
  let(:data) { create_nshift_shipment }
  let(:fulfillment) do
    SolidusNshift::Fulfillment.create!(
      shipment: data[:shipment], connection: data[:connection], rate_selection: data[:selection],
      merchant_reference: SolidusNshift::Reference.for(data[:shipment]), state: "booked",
      provider_shipment_id: "shipment-1"
    )
  end
  let(:client) { instance_double(SolidusNshift::Delivery::Client) }

  before do
    allow(data[:connection]).to receive(:delivery_client).and_return(client)
    allow(client).to receive(:cancel_shipment).and_return(true)
  end

  it "cancels once through a persisted operation" do
    2.times { described_class.new(fulfillment:).call }

    expect(fulfillment.reload.state).to eq("canceled")
    expect(fulfillment.operations.find_by(kind: "delivery_cancel")).to have_attributes(
      status: "succeeded", provider_resource_id: "shipment-1"
    )
    expect(client).to have_received(:cancel_shipment).once
  end

  it "does not repeat cancellation after an ambiguous timeout" do
    allow(client).to receive(:cancel_shipment)
      .and_raise(SolidusNshift::TimeoutUnknownOutcome, "unknown cancellation result")

    expect { 2.times { described_class.new(fulfillment:).call } }
      .to have_enqueued_job(SolidusNshift::ReconcileBookingJob).at_least(:once)

    expect(fulfillment.reload.state).to eq("reconciliation_pending")
    expect(fulfillment.operations.find_by(kind: "delivery_cancel").status).to eq("unknown")
    expect(client).to have_received(:cancel_shipment).once
  end

  it "schedules reconciliation and re-raises unexpected failures after dispatch" do
    allow(client).to receive(:cancel_shipment).and_raise(RuntimeError, "adapter bug")

    expect { described_class.new(fulfillment:).call }
      .to have_enqueued_job(SolidusNshift::ReconcileBookingJob).and raise_error(RuntimeError, "adapter bug")

    expect(fulfillment.reload.state).to eq("reconciliation_pending")
    expect(fulfillment.operations.find_by(kind: "delivery_cancel").status).to eq("unknown")
  end

  it "does not schedule reconciliation when local client construction fails" do
    allow(data[:connection]).to receive(:delivery_client).and_raise(RuntimeError, "client setup failed")

    expect { described_class.new(fulfillment:).call }
      .to raise_error(RuntimeError, "client setup failed")

    expect(fulfillment.reload.state).to eq("booked")
    expect(fulfillment.operations).to be_empty
    expect(SolidusNshift::ReconcileBookingJob).not_to have_been_enqueued
  end
end
