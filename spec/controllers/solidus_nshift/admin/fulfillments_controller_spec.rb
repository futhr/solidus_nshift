# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::Admin::FulfillmentsController, type: :controller do
  render_views
  routes { SolidusNshift::Engine.routes }
  stub_authorization!

  let(:data) { create_nshift_shipment }
  let(:fulfillment) do
    SolidusNshift::Fulfillment.create!(
      shipment: data[:shipment], connection: data[:connection], rate_selection: data[:selection],
      merchant_reference: SolidusNshift::Reference.for(data[:shipment]), state: "reconciliation_pending"
    )
  end

  before do
    allow(controller).to receive(:spree_current_user).and_return(build_stubbed(:admin_user))
  end

  it "renders persisted operation state without provider calls" do
    fulfillment.operations.create!(
      kind: "delivery_booking", status: "unknown", request_fingerprint: "a" * 64,
      error_message: "Ambiguous timeout"
    )

    get :show, params: {id: fulfillment.id}

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Reconciliation pending", "Ambiguous timeout")
  end

  it "queues reconciliation from an authorized action" do
    expect { post :reconcile, params: {id: fulfillment.id} }
      .to have_enqueued_job(SolidusNshift::ReconcileBookingJob).with(fulfillment.id)
    expect(response).to redirect_to(admin_fulfillment_path(fulfillment))
  end
end
