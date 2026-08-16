# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::RateSelection, type: :model do
  subject(:selection) do
    described_class.new(
      shipping_rate: create(:shipping_rate),
      connection: connection,
      session_id: "session-1",
      external_option_id: "option-1",
      service_code: "P19",
      label: "Service point",
      amount: "89.50",
      currency: "SEK",
      context_digest: "a" * 64,
      pickup_points: pickup_points,
      session_expires_at: 3.hours.from_now
    )
  end

  let(:connection) do
    SolidusNshift::Connection.new(
      store: create(:store), name: "Checkout", checkout_enabled: true
    ).tap do |record|
      record.preferred_checkout_client_id = "client"
      record.preferred_checkout_client_secret = "secret"
      record.preferred_checkout_connection_id = "connection"
      record.save!
    end
  end
  let(:pickup_points) do
    [{id: "SE-123", name: "Corner shop", address: {postalCode: "12030"}}]
  end

  it "persists only a pickup point offered with the rate" do
    selection.save!
    selection.select_pickup_point!("SE-123")

    expect(selection.reload.selected_pickup_point).to include("id" => "SE-123", "name" => "Corner shop")
    expect(selection).to be_selection_complete
  end

  it "rejects an arbitrary pickup point identifier" do
    selection.save!

    expect { selection.select_pickup_point!("SE-attacker") }
      .to raise_error(SolidusNshift::ValidationError, /was not offered/)
  end

  it "replaces tampered pickup metadata with the offered point" do
    selection.selected_pickup_point_id = "SE-123"
    selection.selected_pickup_point = {id: "SE-123", name: "Attacker controlled"}
    selection.save!

    expect(selection.selected_pickup_point).to include("name" => "Corner shop")
  end

  it "requires a pickup point only when the option offered points" do
    selection.save!
    expect(selection).not_to be_selection_complete

    selection.pickup_points = []
    expect(selection).to be_selection_complete
  end

  it "expires when either its context or provider session is stale" do
    expect(selection).to be_valid_for(digest: "a" * 64, at: Time.current)
    expect(selection).not_to be_valid_for(digest: "b" * 64, at: Time.current)
    expect(selection).not_to be_valid_for(digest: "a" * 64, at: 4.hours.from_now)
  end
end
