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

  it "authorizes fulfillment administration and the requested mutation" do
    expect(controller).to receive(:authorize!).with(:admin, SolidusNshift::Fulfillment).ordered
    expect(controller).to receive(:authorize!).with(:reconcile, SolidusNshift::Fulfillment).ordered

    post :reconcile, params: {id: fulfillment.id}

    expect(response).to redirect_to(admin_fulfillment_path(fulfillment))
  end

  it "does not claim success when the queue rejects a job" do
    allow(SolidusNshift::ReconcileBookingJob).to receive(:perform_later).and_return(false)

    post :reconcile, params: {id: fulfillment.id}

    expect(response).to redirect_to(admin_fulfillment_path(fulfillment))
    expect(flash[:alert]).to match(/could not be queued/)
  end

  it "uses the configured booking job" do
    job_class = class_double(SolidusNshift::BookShipmentJob, perform_later: true)
    SolidusNshift.configuration.book_shipment_job = -> { job_class }
    fulfillment.update!(state: "unbooked")

    post :book, params: {id: fulfillment.id}

    expect(job_class).to have_received(:perform_later).with(fulfillment.shipment_id)
    expect(response).to redirect_to(admin_fulfillment_path(fulfillment))
  end

  it "refuses an operation that is invalid for the current fulfillment state" do
    fulfillment.update!(state: "unbooked")

    expect { post :cancel, params: {id: fulfillment.id} }
      .not_to have_enqueued_job(SolidusNshift::CancelFulfillmentJob)
    expect(flash[:alert]).to match(/Only booked/)
  end
end
