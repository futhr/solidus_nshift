# frozen_string_literal: true

module SolidusNshift
  class Fulfillment < ::Spree::Base
    STATES = %w[
      unbooked booking partial_created booked reconciliation_pending rejected canceled
    ].freeze

    self.table_name = "solidus_nshift_fulfillments"

    belongs_to :shipment, class_name: "Spree::Shipment", inverse_of: :nshift_fulfillment
    belongs_to :connection, class_name: "SolidusNshift::Connection"
    belongs_to :rate_selection, class_name: "SolidusNshift::RateSelection"
    has_many :operations, class_name: "SolidusNshift::Operation", dependent: :restrict_with_error
    has_many :documents, class_name: "SolidusNshift::Document", dependent: :destroy
    has_many :tracking_events, class_name: "SolidusNshift::TrackingEvent", dependent: :destroy

    validates :merchant_reference, presence: true, uniqueness: {scope: :connection_id}
    validates :shipment_id, uniqueness: true
    validates :rate_selection_id, uniqueness: true
    validates :state, inclusion: {in: STATES}
    validates :tracking_status, inclusion: {in: TrackingEvent::STATUSES}, allow_nil: true

    scope :requiring_reconciliation, -> { where(state: "reconciliation_pending") }

    def booked?
      state == "booked"
    end

    def latest_operation(kind)
      operations.where(kind:).order(revision: :desc).first
    end

    def record_error!(error, state: self.state)
      update!(
        state:,
        last_error_class: error.class.name,
        last_error_code: error.respond_to?(:provider_code) ? error.provider_code : nil,
        last_error_message: error.message.to_s.first(2_000)
      )
    end

    def clear_error_attributes
      {last_error_class: nil, last_error_code: nil, last_error_message: nil}
    end
  end
end
