# frozen_string_literal: true

module SolidusNshift
  class SyncTracking
    def initialize(fulfillment:)
      @fulfillment = fulfillment
      @client = fulfillment.connection.shipment_data_client
    end

    def call
      locate_shipment! if @fulfillment.shipment_data_uuid.blank?
      events = @client.events(shipment_uuid: @fulfillment.shipment_data_uuid)
      Fulfillment.transaction do
        events.each { |event| persist_event(event) }
        update_tracking_status(events)
        @fulfillment.update!(tracking_synced_at: Time.current)
      end
      @fulfillment
    end

    private

    def locate_shipment!
      reference = @fulfillment.merchant_reference
      anchor = @fulfillment.shipment.order.completed_at || @fulfillment.created_at || Time.current
      response = @client.find_by_order_number(
        order_number: reference,
        start_time: anchor - 1.day,
        end_time: Time.current + 1.day
      )
      uuid = ShipmentData::ShipmentLocator.new.call(response, reference:)
      raise TrackingError, "nShift Shipment Data did not find the booked shipment" unless uuid

      @fulfillment.update!(shipment_data_uuid: uuid)
    end

    def persist_event(event)
      record = @fulfillment.tracking_events.find_or_initialize_by(external_event_id: event.external_id)
      record.assign_attributes(
        code: event.code.presence || "UNKNOWN",
        status: event.status,
        occurred_at: event.occurred_at,
        description: event.description,
        provider_metadata: {"raw_code" => event.raw_code}
      )
      record.save!
    end

    def update_tracking_status(events)
      current = @fulfillment.tracking_status
      return if ShipmentData::Event::TERMINAL.include?(current)

      candidate = events.max_by { |event| [event.precedence, event.occurred_at] }
      return unless candidate
      return if candidate.precedence < ShipmentData::Event::PRECEDENCE.fetch(current.to_s, 0)

      @fulfillment.tracking_status = candidate.status
    end
  end
end
