# frozen_string_literal: true

module SolidusNshift
  class TrackingEvent < ::Spree::Base
    STATUSES = ShipmentData::Event::PRECEDENCE.keys.freeze

    self.table_name = "solidus_nshift_tracking_events"

    attribute :provider_metadata, default: -> { {} }

    belongs_to :fulfillment, class_name: "SolidusNshift::Fulfillment", inverse_of: :tracking_events

    validates :external_event_id, :code, :status, :occurred_at, presence: true
    validates :status, inclusion: {in: STATUSES}
  end
end
