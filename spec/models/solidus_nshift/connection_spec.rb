# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::Connection, type: :model do
  subject(:connection) do
    described_class.new(
      store: create(:store),
      name: "Nordic production",
      checkout_enabled: true,
      delivery_enabled: false,
      tracking_enabled: false
    ).tap do |record|
      record.preferred_checkout_client_id = "checkout-client"
      record.preferred_checkout_client_secret = "checkout-secret"
      record.preferred_checkout_connection_id = "checkout-connection"
    end
  end

  it "validates only credentials for enabled capabilities" do
    expect(connection).to be_valid

    connection.checkout_enabled = false
    connection.delivery_enabled = true
    expect(connection).not_to be_valid
    expect(connection.errors.attribute_names).to include(
      :preferred_delivery_api_key_id,
      :preferred_delivery_api_key_secret,
      :preferred_delivery_developer_id,
      :preferred_delivery_sender_name,
      :preferred_delivery_sender_address1,
      :preferred_delivery_sender_zipcode,
      :preferred_delivery_sender_city,
      :preferred_delivery_sender_country
    )
  end

  it "requires an uppercase two-letter Delivery sender country" do
    data = create_nshift_shipment
    data[:connection].preferred_delivery_sender_country = "swe"

    expect(data[:connection]).not_to be_valid
    expect(data[:connection].errors[:preferred_delivery_sender_country])
      .to include("must be a two-letter uppercase country code")
  end

  it "requires at least one enabled capability" do
    connection.checkout_enabled = false

    expect(connection).not_to be_valid
    expect(connection.errors[:base]).to include("enable at least one nShift capability")
  end

  it "does not disclose credentials when inspected" do
    connection.save!

    expect(connection.inspect).not_to include("checkout-secret")
    expect(connection.inspect).to include("Nordic production")
  end
end
