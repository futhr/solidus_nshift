# frozen_string_literal: true

module SolidusNshift
  class TrackingEvent < ::Spree::Base
    self.table_name = "solidus_nshift_tracking_events"

    belongs_to :fulfillment, class_name: "SolidusNshift::Fulfillment", inverse_of: :tracking_events

    validates :external_event_id, :code, :status, :occurred_at, presence: true
    validates :external_event_id, uniqueness: {scope: :fulfillment_id}
  end
end
