# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::Admin::DocumentsController, type: :controller do
  routes { SolidusNshift::Engine.routes }
  stub_authorization!

  let(:data) { create_nshift_shipment }
  let(:fulfillment) do
    SolidusNshift::Fulfillment.create!(
      shipment: data[:shipment], connection: data[:connection], rate_selection: data[:selection],
      merchant_reference: SolidusNshift::Reference.for(data[:shipment]), state: "booked",
      provider_shipment_id: "shipment-1"
    )
  end
  let(:document) do
    fulfillment.documents.create!(
      provider_document_id: "document-1", description: "Label", format: "pdf", content_type: "application/pdf"
    )
  end

  before do
    allow(controller).to receive(:spree_current_user).and_return(build_stubbed(:admin_user))
  end

  it "streams the provider document through the authorized admin controller" do
    content = SolidusNshift::Delivery::DocumentContent.new(body: "%PDF-synthetic".b, content_type: "application/pdf")
    allow(SolidusNshift::DownloadDocument).to receive(:new)
      .with(document: an_instance_of(SolidusNshift::Document))
      .and_return(instance_double(SolidusNshift::DownloadDocument, call: content))

    get :show, params: {id: document.id}

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")
    expect(response.body).to start_with("%PDF-")
    expect(response.headers["Content-Disposition"]).to include("attachment")
  end
end
