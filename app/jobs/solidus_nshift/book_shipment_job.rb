# frozen_string_literal: true

module SolidusNshift
  class BookShipmentJob < ActiveJob::Base
    queue_as :default

    discard_on ActiveRecord::RecordNotFound

    def perform(shipment_id)
      BookingService.new(shipment: Spree::Shipment.find(shipment_id)).call
    end
  end
end
