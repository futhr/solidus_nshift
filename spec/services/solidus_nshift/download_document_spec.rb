# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::DownloadDocument do
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
  let(:client) { instance_double(SolidusNshift::Delivery::Client) }

  before do
    allow(data[:connection]).to receive(:delivery_client).and_return(client)
  end

  it "downloads by scoped provider identifiers rather than trusting an href" do
    content = SolidusNshift::Delivery::DocumentContent.new(body: "%PDF-synthetic".b, content_type: "application/pdf")
    allow(client).to receive(:download_document).and_return(content)

    expect(described_class.new(document:).call).to eq(content)
    expect(client).to have_received(:download_document).with(
      shipment_id: "shipment-1", document_id: "document-1", format: "pdf"
    )
  end
end
