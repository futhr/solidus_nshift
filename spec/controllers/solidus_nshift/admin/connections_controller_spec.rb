# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::Admin::ConnectionsController, type: :controller do
  render_views
  routes { SolidusNshift::Engine.routes }
  stub_authorization!

  let(:user) { build_stubbed(:admin_user) }

  before do
    allow(controller).to receive(:spree_current_user).and_return(user)
  end

  it "renders the connection list without exposing secret values" do
    data = create_nshift_shipment

    get :index

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(data[:connection].name)
    expect(response.body).not_to include("checkout-secret", "delivery-secret")
  end

  it "authorizes connection administration and the requested action" do
    expect(controller).to receive(:authorize!).with(:admin, SolidusNshift::Connection).ordered
    expect(controller).to receive(:authorize!).with(:index, SolidusNshift::Connection).ordered

    get :index

    expect(response).to have_http_status(:ok)
  end

  it "retains encrypted credentials when blank secret fields are submitted" do
    data = create_nshift_shipment
    connection = data[:connection]

    patch :update, params: {
      id: connection.id,
      solidus_nshift_connection: {
        name: "Renamed connection",
        preferred_checkout_client_secret: "",
        preferred_delivery_api_key_id: "",
        preferred_delivery_api_key_secret: ""
      }
    }

    expect(response).to redirect_to(admin_connections_path)
    expect(connection.reload).to have_attributes(name: "Renamed connection")
    expect(connection.preferred_checkout_client_secret).to eq("checkout-secret")
    expect(connection.preferred_delivery_api_key_secret).to eq("delivery-secret")
  end

  it "renders secret inputs blank on edit" do
    connection = create_nshift_shipment[:connection]

    get :edit, params: {id: connection.id}

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("checkout-secret", "delivery-secret", "delivery-key")
    expect(response.body).to include("Leave blank to keep the stored value")
  end
end
