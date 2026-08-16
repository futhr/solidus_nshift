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
end
