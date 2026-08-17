# frozen_string_literal: true

module SolidusNshift
  module ShippingRateExtension
    extend ActiveSupport::Concern

    included do
      has_one :nshift_selection,
        class_name: "SolidusNshift::RateSelection",
        foreign_key: :shipping_rate_id,
        inverse_of: :shipping_rate,
        dependent: :destroy,
        autosave: true
    end
  end
end
