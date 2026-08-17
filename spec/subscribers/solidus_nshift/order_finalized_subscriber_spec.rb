# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::OrderFinalizedSubscriber do
  it "enqueues only shipments carrying a selected nShift rate" do
    data = create_nshift_shipment
    subscriber = described_class.new
    bus = Omnes::Bus.new
    bus.register(:order_finalized)
    subscriber.subscribe_to(bus)

    expect { bus.publish(:order_finalized, order: data[:order]) }
      .to have_enqueued_job(SolidusNshift::BookShipmentJob).with(data[:shipment].id)
  end

  it "ignores ordinary Solidus shipping rates" do
    order = create(:order_with_line_items)
    subscriber = described_class.new
    bus = Omnes::Bus.new
    bus.register(:order_finalized)
    subscriber.subscribe_to(bus)

    expect { bus.publish(:order_finalized, order:) }
      .not_to have_enqueued_job(SolidusNshift::BookShipmentJob)
  end

  it "persists a recoverable intent when the booking queue is unavailable" do
    data = create_nshift_shipment
    job_class = class_double(SolidusNshift::BookShipmentJob)
    allow(job_class).to receive(:perform_later).and_raise(ActiveJob::EnqueueError, "queue unavailable")
    SolidusNshift.configuration.book_shipment_job = -> { job_class }
    bus = Omnes::Bus.new
    bus.register(:order_finalized)
    described_class.new.subscribe_to(bus)

    expect { bus.publish(:order_finalized, order: data[:order]) }.not_to raise_error

    expect(data[:shipment].reload.nshift_fulfillment).to have_attributes(
      state: "unbooked",
      connection_id: data[:connection].id,
      rate_selection_id: data[:selection].id
    )
  end

  it "installs idempotently across Rails code reloads" do
    data = create_nshift_shipment
    bus = Omnes::Bus.new
    bus.register(:order_finalized)

    2.times { described_class.install(bus) }

    expect { bus.publish(:order_finalized, order: data[:order]) }
      .to have_enqueued_job(SolidusNshift::BookShipmentJob).exactly(:once)
  end
end
