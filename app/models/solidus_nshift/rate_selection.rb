# frozen_string_literal: true

module SolidusNshift
  class RateSelection < ::Spree::Base
    self.table_name = "solidus_nshift_rate_selections"

    attribute :pickup_points, default: -> { [] }
    attribute :selected_pickup_point, default: -> { {} }
    attribute :provider_metadata, default: -> { {} }

    belongs_to :shipping_rate, class_name: "Spree::ShippingRate", inverse_of: :nshift_selection
    belongs_to :connection, class_name: "SolidusNshift::Connection"
    has_one :fulfillment, class_name: "SolidusNshift::Fulfillment", dependent: :restrict_with_error

    validates :session_id, :external_option_id, :service_code, :label, :context_digest, presence: true
    validates :context_digest, format: {with: /\A[0-9a-f]{64}\z/}
    validates :currency, format: {with: /\A[A-Z]{3}\z/}
    validates :amount, numericality: {greater_than_or_equal_to: 0}
    validates :shipping_rate_id, uniqueness: true
    validate :pickup_points_are_valid
    validate :selected_point_was_offered

    def select_pickup_point!(pickup_point_id)
      value = pickup_point_id.to_s
      point = normalized_pickup_points.find { |candidate| candidate.fetch("id") == value }
      raise ValidationError, "pickup point was not offered for this shipping option" unless point

      update!(selected_pickup_point_id: value, selected_pickup_point: point)
    end

    def pickup_required?
      normalized_pickup_points.any?
    end

    def selection_complete?
      !pickup_required? || selected_pickup_point_id.present?
    end

    def valid_for?(digest:, at: Time.current)
      context_digest == digest && session_expires_at > at
    end

    private

    def normalized_pickup_points
      return [] unless pickup_points.is_a?(Array)

      pickup_points.filter_map { |point| point.stringify_keys if point.is_a?(Hash) }
    end

    def pickup_points_are_valid
      valid = pickup_points.is_a?(Array) && pickup_points.all? do |point|
        point.is_a?(Hash) && point.stringify_keys["id"].present?
      end
      errors.add(:pickup_points, "must be an array of points with IDs") unless valid
    end

    def selected_point_was_offered
      return if selected_pickup_point_id.blank?
      offered_point = normalized_pickup_points.find { |point| point.fetch("id") == selected_pickup_point_id }
      if offered_point
        self.selected_pickup_point = offered_point
        return
      end

      errors.add(:selected_pickup_point_id, "was not offered for this option")
    end
  end
end
