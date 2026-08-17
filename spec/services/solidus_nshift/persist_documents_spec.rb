# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::PersistDocuments do
  let(:data) { create_nshift_shipment }
  let(:fulfillment) do
    SolidusNshift::Fulfillment.create!(
      shipment: data[:shipment], connection: data[:connection], rate_selection: data[:selection],
      merchant_reference: SolidusNshift::Reference.for(data[:shipment])
    )
  end
  let(:provider_document) do
    SolidusNshift::Delivery::Document.from_hash(
      "id" => "document-1", "description" => "Shipping label", "type" => "PDF"
    )
  end

  it "creates once and refreshes mutable metadata" do
    described_class.new(fulfillment:, documents: [provider_document]).call
    changed = provider_document.with(description: "Updated label")

    described_class.new(fulfillment:, documents: [changed]).call

    expect(fulfillment.documents.count).to eq(1)
    expect(fulfillment.documents.first).to have_attributes(description: "Updated label", format: "pdf")
  end

  it "survives concurrent insertion of the same provider document", :concurrency do
    skip "unique-key concurrency is certified on PostgreSQL" unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"

    fulfillment_id = fulfillment.id
    ready = Queue.new
    release = Queue.new
    workers = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          record = SolidusNshift::Fulfillment.find(fulfillment_id)
          ready << true
          release.pop
          described_class.new(fulfillment: record, documents: [provider_document]).call
        end
      end
    end
    2.times { ready.pop }
    2.times { release << true }

    expect(workers.map(&:value)).to all(be_an(Array))
    expect(fulfillment.documents.reload.count).to eq(1)
  end
end
