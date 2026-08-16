# frozen_string_literal: true

require "rails_helper"

RSpec.describe "nShift pickup selection", type: :request do
  let(:data) { create_nshift_shipment(pickup: true) }
  let(:selection) { data[:selection] }
  let(:path) { "/solidus_nshift/rate_selections/#{selection.id}.json" }

  before do
    selection.update!(selected_pickup_point_id: nil, selected_pickup_point: {})
  end

  it "accepts a point offered to the current order token" do
    patch path,
      params: {pickup_point_id: "SE-10001"},
      headers: {"X-Spree-Order-Token" => data[:order].guest_token}

    expect(response).to have_http_status(:ok)
    expect(selection.reload.selected_pickup_point).to include("id" => "SE-10001", "name" => "Synthetic Market")
  end

  it "rejects a token from another order" do
    patch path,
      params: {pickup_point_id: "SE-10001"},
      headers: {"X-Spree-Order-Token" => create(:order).guest_token}

    expect(response).to have_http_status(:forbidden)
    expect(selection.reload.selected_pickup_point_id).to be_nil
  end

  it "rejects a point that was not returned for this option" do
    patch path,
      params: {pickup_point_id: "SE-attacker"},
      headers: {"X-Spree-Order-Token" => data[:order].guest_token}

    expect(response).to have_http_status(:unprocessable_content)
    expect(selection.reload.selected_pickup_point_id).to be_nil
  end

  it "rejects changes to an unselected rate" do
    selection.shipping_rate.update!(selected: false)

    patch path,
      params: {pickup_point_id: "SE-10001"},
      headers: {"X-Spree-Order-Token" => data[:order].guest_token}

    expect(response).to have_http_status(:unprocessable_content)
  end
end
