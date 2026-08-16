# frozen_string_literal: true

module NshiftFulfillmentHelpers
  def nshift_fixture_json(path)
    JSON.parse(File.binread(File.expand_path("../fixtures/nshift/#{path}", __dir__)))
  end

  def create_nshift_shipment(delivery_enabled: true, tracking_enabled: false, pickup: false)
    address = create(:address, country_iso_code: "SE", zipcode: "113 59")
    store = create(:store, default_currency: "SEK")
    connection = SolidusNshift::Connection.new(
      store:,
      name: "Nordic fulfillment",
      checkout_enabled: true,
      delivery_enabled:,
      tracking_enabled:
    )
    configure_checkout(connection)
    configure_delivery(connection) if delivery_enabled
    configure_tracking(connection) if tracking_enabled
    connection.save!

    variant = create(:variant, weight: "0.75", depth: "20", width: "15", height: "10")
    calculator = Spree::Calculator::Shipping::NshiftCheckout.new
    calculator.preferred_connection_id = connection.id
    calculator.preferred_option_kind = pickup ? "pickup" : "home"
    calculator.preferred_weight_unit = "kg"
    calculator.preferred_dimension_unit = "cm"
    calculator.preferred_locale = "sv"
    shipping_method = create(
      :shipping_method,
      calculator:,
      shipping_categories: [variant.shipping_category]
    )
    store.shipping_methods << shipping_method
    order = create(
      :order_with_line_items,
      store:,
      currency: "SEK",
      ship_address: address,
      shipping_method:,
      line_items_attributes: [{variant:, quantity: 2, price: "199.95"}]
    )
    shipment = order.shipments.first
    rate = shipment.selected_shipping_rate
    request = SolidusNshift::Solidus::PackageSerializer.new(package: shipment.to_package, calculator:).call
    points = pickup ? [pickup_point] : []
    selection = SolidusNshift::RateSelection.create!(
      shipping_rate: rate,
      connection:,
      session_id: "session-1",
      external_option_id: pickup ? "pickup-option" : "home-option",
      service_code: "P19",
      carrier_code: "POSTNORD",
      carrier_name: "PostNord",
      label: pickup ? "Collect nearby" : "Home delivery",
      amount: "59.00",
      currency: "SEK",
      context_digest: request.context_digest,
      pickup_points: points,
      selected_pickup_point_id: pickup ? "SE-10001" : nil,
      selected_pickup_point: pickup ? pickup_point : {},
      session_expires_at: 3.hours.from_now
    )
    {shipment:, selection:, connection:, order:, rate:, calculator:}
  end

  private

  def configure_checkout(connection)
    connection.preferred_checkout_client_id = "checkout-client"
    connection.preferred_checkout_client_secret = "checkout-secret"
    connection.preferred_checkout_connection_id = "checkout-connection"
  end

  def configure_delivery(connection)
    connection.preferred_delivery_api_key_id = "delivery-key"
    connection.preferred_delivery_api_key_secret = "delivery-secret"
    connection.preferred_delivery_developer_id = "solidus-nshift-tests"
    connection.preferred_delivery_sender_quick_id = "1"
    connection.preferred_delivery_test_mode = true
  end

  def configure_tracking(connection)
    connection.preferred_tracking_client_id = "tracking-client"
    connection.preferred_tracking_client_secret = "tracking-secret"
  end

  def pickup_point
    {
      id: "SE-10001",
      name: "Synthetic Market",
      address1: "Examplegatan 1",
      postal_code: "113 59",
      city: "Stockholm",
      country_code: "SE"
    }
  end
end

RSpec.configure do |config|
  config.include NshiftFulfillmentHelpers
end
