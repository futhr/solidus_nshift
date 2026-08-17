# frozen_string_literal: true

module SolidusNshift
  class OrderFinalizedSubscriber
    include Omnes::Subscriber

    SUBSCRIPTION_ID = :solidus_nshift_order_finalized_enqueue_bookings

    handle :order_finalized,
      with: :enqueue_bookings,
      id: SUBSCRIPTION_ID

    def self.install(bus)
      existing = bus.subscription(SUBSCRIPTION_ID)
      bus.unsubscribe(existing) if existing

      new.subscribe_to(bus)
    end

    def enqueue_bookings(event)
      event[:order].shipments.find_each do |shipment|
        next unless shipment.selected_shipping_rate&.nshift_selection

        fulfillment = FulfillmentIntent.new(shipment:).call
        JobEnqueuer.call(
          job_class: SolidusNshift.configuration.book_shipment_job.call,
          arguments: [shipment.id],
          operation: "book_shipment",
          metadata: {fulfillment_id: fulfillment.id, connection_id: fulfillment.connection_id}
        )
      end
    end
  end
end
