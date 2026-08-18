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
      sessionId: "session-1", optionId: "pickup-option", orderId: fulfillment.merchant_reference
    )
    expect(checkout_payload[:pickupPointId]).to eq("SE-10001")
    expect(delivery_payload[:shipment]).to include(orderNo: fulfillment.merchant_reference)
    expect(delivery_payload.dig(:shipment, :agent)).to include(quickId: "SE-10001")
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

  it "keeps a successful booking committed when tracking enqueueing fails" do
    data = create_nshift_shipment(tracking_enabled: true)
    allow(data[:connection]).to receive(:checkout_client).and_return(checkout_client)
    allow(data[:connection]).to receive(:delivery_client).and_return(delivery_client)
    job_class = class_double(SolidusNshift::SyncTrackingJob)
    allow(job_class).to receive(:perform_later).and_raise(ActiveJob::EnqueueError, "queue unavailable")
    SolidusNshift.configuration.sync_tracking_job = -> { job_class }

    fulfillment = described_class.new(shipment: data[:shipment]).call

    expect(fulfillment.reload).to have_attributes(state: "booked", provider_shipment_id: "10252317")
    expect(fulfillment.operations.find_by(kind: "delivery_booking").status).to eq("succeeded")
    expect(SolidusNshift::ReconcileBookingJob).not_to have_been_enqueued
  end

  it "does not retry forever when a merchant reference belongs to another shipment" do
    allow(SolidusNshift::Fulfillment).to receive(:find_or_create_by!)
      .and_raise(ActiveRecord::RecordNotUnique, "duplicate reference")
    allow(SolidusNshift::Fulfillment).to receive(:find_by).and_return(nil)

    expect { described_class.new(shipment: data[:shipment]).call }
      .to raise_error(SolidusNshift::ShipmentConflictError, /different shipment/)
    expect(SolidusNshift::Fulfillment).to have_received(:find_or_create_by!).once
    expect(checkout_client).not_to have_received(:create_partial_shipment)
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

  it "permits a safe retry after a definitive Delivery rejection" do
    attempts = 0
    allow(delivery_client).to receive(:create_shipment) do
      attempts += 1
      if attempts == 1
        raise SolidusNshift::ValidationError.new("invalid credentials", provider_code: "CONFIG")
      end

      provider_shipment
    end
    allow_any_instance_of(SolidusNshift::Connection).to receive(:delivery_client).and_return(delivery_client)

    first_result = described_class.new(shipment: data[:shipment]).call
    data[:connection].update!(preferred_delivery_developer_id: "corrected-developer-id")
    data[:selection].update!(session_expires_at: 1.minute.ago)
    second_result = described_class.new(shipment: data[:shipment]).call

    expect(first_result.state).to eq("rejected")
    expect(second_result.reload.state).to eq("booked")
    expect(second_result.operations.where(kind: "delivery_booking").order(:revision).pluck(:revision, :status, :attempts))
      .to eq([
        [1, "rejected", 1],
        [2, "succeeded", 1]
      ])
    expect(second_result.latest_operation("delivery_booking")).to have_attributes(
      status: "succeeded", revision: 2
    )
  end

  it "rejects stale selection context before any provider mutation" do
    data[:order].update!(ship_address: create(:address, country_iso_code: "SE", zipcode: "411 01"))

    expect { described_class.new(shipment: data[:shipment]).call }
      .to raise_error(SolidusNshift::StaleSessionError)
    expect(checkout_client).not_to have_received(:create_partial_shipment)
  end

  it "revalidates a delivery-only intent created before the booking job runs" do
    connection.update!(checkout_enabled: false)
    SolidusNshift::FulfillmentIntent.new(shipment: data[:shipment]).call
    data[:order].update!(ship_address: create(:address, country_iso_code: "SE", zipcode: "411 01"))

    expect { described_class.new(shipment: data[:shipment]).call }
      .to raise_error(SolidusNshift::StaleSessionError)
    expect(delivery_client).not_to have_received(:create_shipment)
  end

  it "does not schedule reconciliation when local Delivery payload construction fails" do
    allow(SolidusNshift.configuration).to receive(:parcel_builder)
      .and_return(->(_shipment) { raise "merchant parcel builder failed" })

    expect { described_class.new(shipment: data[:shipment]).call }
      .to raise_error(RuntimeError, "merchant parcel builder failed")

    fulfillment = data[:shipment].reload.nshift_fulfillment
    expect(fulfillment).to have_attributes(state: "partial_created", checkout_partial_shipment_id: "partial-1")
    expect(fulfillment.operations.pluck(:kind, :status)).to eq([["checkout_partial", "succeeded"]])
    expect(delivery_client).not_to have_received(:create_shipment)
    expect(SolidusNshift::ReconcileBookingJob).not_to have_been_enqueued
  end
end
