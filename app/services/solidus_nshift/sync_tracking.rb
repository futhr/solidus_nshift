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
        update_tracking_status
        @fulfillment.update!(tracking_synced_at: Time.current)
      end
      @fulfillment
    end

    private

    def locate_shipment!
      reference = @fulfillment.merchant_reference
      anchor = @fulfillment.created_at || @fulfillment.shipment.order.completed_at || Time.current
      response = @client.find_by_order_number(
        order_number: reference,
        start_time: anchor - 1.day,
        end_time: [Time.current + 1.day, anchor + 30.days].min
      )
      uuid = ShipmentData::ShipmentLocator.new.call(response, reference:)
      raise TrackingError, "nShift Shipment Data did not find the booked shipment" unless uuid

      @fulfillment.update!(shipment_data_uuid: uuid)
    end

    def persist_event(event)
      attributes = {
        code: event.code.presence || "UNKNOWN",
        status: event.status,
        occurred_at: event.occurred_at,
        description: event.description,
        provider_metadata: {"raw_code" => event.raw_code}
      }
      record = @fulfillment.tracking_events.create_or_find_by!(external_event_id: event.external_id) do |candidate|
        candidate.assign_attributes(attributes)
      end
      record.update!(attributes)
    end

    def update_tracking_status
      current = @fulfillment.tracking_status
      return if ShipmentData::Event::TERMINAL.include?(current)

      @fulfillment.tracking_events.reset
      candidate = @fulfillment.tracking_events.reject { |event| event.status == "unknown" }.max_by do |event|
        [ShipmentData::Event::PRECEDENCE.fetch(event.status, 0), event.occurred_at]
      end
      return unless candidate

      @fulfillment.tracking_status = candidate.status
    end
  end
end
