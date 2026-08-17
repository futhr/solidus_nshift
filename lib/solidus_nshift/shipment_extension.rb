# frozen_string_literal: true

module SolidusNshift
  module ShipmentExtension
    extend ActiveSupport::Concern

    included do
      has_one :nshift_fulfillment,
        class_name: "SolidusNshift::Fulfillment",
        foreign_key: :shipment_id,
        inverse_of: :shipment,
        dependent: :restrict_with_error
    end
  end
end
