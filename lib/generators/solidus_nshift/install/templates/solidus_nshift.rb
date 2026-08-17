# frozen_string_literal: true

SolidusNshift.configure do |config|
  # Keep this shorter than the four-hour nShift Checkout session lifetime.
  config.rate_cache_ttl = 5.minutes

  # Override this for merchant-specific multi-parcel packing. Each element must
  # contain :weight in kilograms and may contain :copies and :contents. A custom
  # builder may accept weight_unit: when it needs the calculator's source unit.
  # config.parcel_builder = ->(shipment) { [{weight: shipment.to_package.weight, copies: 1}] }
end
