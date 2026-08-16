# frozen_string_literal: true

module SolidusNshift
  class OrderFinalizedSubscriber
    include Omnes::Subscriber

    handle :order_finalized,
      with: :enqueue_bookings,
      id: :solidus_nshift_order_finalized_enqueue_bookings

    def enqueue_bookings(event)
      event[:order].shipments.find_each do |shipment|
        next unless shipment.selected_shipping_rate&.nshift_selection

        SolidusNshift.configuration.book_shipment_job.call.perform_later(shipment.id)
      end
    end
  end
end
