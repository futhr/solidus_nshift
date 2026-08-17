# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::RefreshDocuments do
  let(:data) { create_nshift_shipment }
  let(:fulfillment) do
    SolidusNshift::Fulfillment.create!(
      shipment: data[:shipment], connection: data[:connection], rate_selection: data[:selection],
      merchant_reference: SolidusNshift::Reference.for(data[:shipment]), state: "booked",
      provider_shipment_id: "shipment-1"
    )
  end
  let(:client) { instance_double(SolidusNshift::Delivery::Client) }
  let(:documents) do
    value = nshift_fixture_json("shipments/booked_multi_parcel.json").first
    SolidusNshift::Delivery::Shipment.from_hash(value).documents
  end

  before do
    allow(data[:connection]).to receive(:delivery_client).and_return(client)
  end

  it "refreshes every provider document without creating a shipment" do
    allow(client).to receive(:list_documents).with(shipment_id: "shipment-1").and_return(documents)

    result = described_class.new(fulfillment:).call

    expect(result.map(&:provider_document_id)).to match_array(documents.map(&:id))
    expect(client).to have_received(:list_documents).once
  end

  it "rejects an unbooked fulfillment before calling Delivery" do
    fulfillment.update!(provider_shipment_id: nil, state: "unbooked")
    expect(client).not_to receive(:list_documents)

    expect { described_class.new(fulfillment:).call }
      .to raise_error(SolidusNshift::ValidationError, /has not been booked/)
  end
end
