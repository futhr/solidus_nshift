# frozen_string_literal: true

require "rails_helper"

RSpec.describe "nShift Checkout rates" do
  let(:store) { create(:store, default_currency: "SEK") }
  let!(:ship_address) { create(:address, country_iso_code: "SE", zipcode: "113 59") }
  let(:connection) do
    SolidusNshift::Connection.new(
      store:, name: "Nordic checkout", checkout_enabled: true
    ).tap do |record|
      record.preferred_checkout_client_id = "client"
      record.preferred_checkout_client_secret = "secret"
      record.preferred_checkout_connection_id = "connection-1"
      record.save!
    end
  end
  let(:variant) do
    create(:variant, weight: "0.75", depth: "20", width: "15", height: "10")
  end
  let(:pickup_calculator) do
    Spree::Calculator::Shipping::NshiftCheckout.new.tap do |record|
      record.preferred_connection_id = connection.id
      record.preferred_option_kind = "pickup"
      record.preferred_weight_unit = "kg"
      record.preferred_dimension_unit = "cm"
      record.preferred_locale = "sv"
    end
  end
  let(:pickup_method) do
    create(
      :shipping_method,
      name: "Collect nearby",
      calculator: pickup_calculator,
      shipping_categories: [variant.shipping_category]
    )
  end
  let(:home_method) do
    calculator = Spree::Calculator::Shipping::NshiftCheckout.new
    calculator.preferred_connection_id = connection.id
    calculator.preferred_option_kind = "home"
    calculator.preferred_weight_unit = "kg"
    calculator.preferred_dimension_unit = "cm"
    calculator.preferred_locale = "sv"
    create(
      :shipping_method,
      name: "Home delivery",
      calculator:,
      shipping_categories: [variant.shipping_category]
    )
  end
  let(:order) do
    create(
      :order_with_line_items,
      store:,
      currency: "SEK",
      ship_address:,
      shipping_method: pickup_method,
      line_items_attributes: [{variant:, quantity: 2, price: "199.95"}]
    )
  end
  let(:package) { order.shipments.first.to_package }
  let(:session) do
    SolidusNshift::Checkout::Session.new(
      id: "session-1", expires_at: 3.hours.from_now, checkout_configuration_id: "checkout-1"
    )
  end
  let(:pickup_point) do
    SolidusNshift::Checkout::PickupPoint.new(
      id: "SE-10001", name: "Synthetic Market", address1: "Examplegatan 1",
      postal_code: "113 59", city: "Stockholm", country_code: "SE"
    )
  end
  let(:options) do
    [
      shipping_option(id: "pickup", label: "Collect nearby", price: "59.00", pickup_points: [pickup_point]),
      shipping_option(id: "home", label: "Home delivery", price: "89.50")
    ]
  end
  let(:client) do
    instance_double(SolidusNshift::Checkout::Client).tap do |fake|
      allow(fake).to receive(:create_session).and_return(session)
      allow(fake).to receive(:shipping_options).and_return(options)
    end
  end

  before do
    store.shipping_methods << [pickup_method, home_method]
    order.shipments.first.shipping_rates.delete_all
    allow(connection).to receive(:checkout_client).and_return(client)
    allow(connection).to receive(:delivery_client).and_raise("rating must never book")
    allow(SolidusNshift::Connection).to receive(:find_by).with(id: connection.id).and_return(connection)
  end

  it "maps exact-price option families onto distinct configured shipping methods" do
    rates = estimator.shipping_rates(package, false)

    expect(rates.map(&:cost)).to contain_exactly(BigDecimal("59.0"), BigDecimal("89.5"))
    expect(rates.map(&:shipping_method)).to contain_exactly(pickup_method, home_method)
    expect(rates.map { |rate| rate.nshift_selection.external_option_id }).to contain_exactly("pickup", "home")
    expect(rates.find { |rate| rate.cost == 59 }.nshift_selection.pickup_points.first).to include("id" => "SE-10001")
  end

  it "persists the immutable quote context with the selected shipping rate" do
    rate = estimator.shipping_rates(package, false).first
    rate.shipment = order.shipments.first
    rate.save!

    expect(rate.reload.nshift_selection).to have_attributes(
      connection_id: connection.id,
      session_id: "session-1",
      currency: "SEK",
      context_digest: a_string_matching(/\A[0-9a-f]{64}\z/)
    )
  end

  it "caches identical rating requests without booking a shipment" do
    2.times { estimator.shipping_rates(package, false) }

    expect(client).to have_received(:create_session).once
    expect(client).to have_received(:shipping_options).once
    expect(connection).not_to have_received(:delivery_client)
  end

  it "invalidates the cache context when the destination changes" do
    first_digest = estimator.shipping_rates(package, false).first.nshift_selection.context_digest
    order.update!(ship_address: create(:address, country_iso_code: "SE", zipcode: "411 01"))
    second_digest = estimator.shipping_rates(order.shipments.first.to_package, false).first.nshift_selection.context_digest

    expect(second_digest).not_to eq(first_digest)
    expect(client).to have_received(:create_session).twice
  end

  it "fails closed for provider and currency errors while preserving local rates" do
    local_method = create(
      :shipping_method,
      name: "Flat rate",
      cost: "25.00",
      currency: "SEK",
      shipping_categories: [variant.shipping_category]
    )
    store.shipping_methods << local_method
    allow(client).to receive(:shipping_options).and_raise(SolidusNshift::TransportError, "timed out")

    rates = estimator.shipping_rates(package, false)

    expect(rates.map(&:shipping_method)).to eq([local_method])
  end

  it "extends the configured estimator without replacing merchant behavior" do
    custom_estimator_class = Class.new(Spree::Config.stock.estimator_class) do
      attr_reader :merchant_estimator_called

      private

      def calculate_shipping_rates(package)
        @merchant_estimator_called = true
        super
      end
    end
    custom_estimator = custom_estimator_class.new

    rates = custom_estimator.shipping_rates(package, false)

    expect(custom_estimator.merchant_estimator_called).to be(true)
    expect(rates.map(&:shipping_method)).to contain_exactly(pickup_method, home_method)
  end

  it "does not replace Solidus' configured estimator class" do
    expect(Spree::Config.stock.estimator_class).to eq(Spree::Stock::Estimator)
  end

  def shipping_option(id:, label:, price:, pickup_points: [])
    SolidusNshift::Checkout::ShippingOption.new(
      external_id: id,
      service_code: "P19",
      carrier_code: "POSTNORD",
      carrier_name: "PostNord",
      label:,
      price: BigDecimal(price),
      currency: "SEK",
      delivery_estimate: "1-2 days",
      pickup_points:,
      metadata: {},
      session_id: "session-1"
    )
  end

  def estimator
    Spree::Config.stock.estimator_class.new
  end
end
