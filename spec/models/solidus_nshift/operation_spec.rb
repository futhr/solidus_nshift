# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::Operation, type: :model do
  let(:data) { create_nshift_shipment }
  let(:fulfillment) do
    SolidusNshift::Fulfillment.create!(
      shipment: data[:shipment], connection: data[:connection], rate_selection: data[:selection],
      merchant_reference: SolidusNshift::Reference.for(data[:shipment])
    )
  end
  let(:operation) do
    described_class.create!(
      fulfillment:, kind: "delivery_booking", request_fingerprint: "a" * 64
    )
  end

  it "allows one worker to claim a pending operation" do
    expect(operation.claim!).to be(true)
    expect(operation.reload).to have_attributes(status: "in_progress", attempts: 1)
  end

  it "requires reconciliation instead of redispatching an in-progress operation" do
    operation.claim!

    expect { operation.claim! }.to raise_error(SolidusNshift::ReconciliationRequired)
  end

  it "treats a succeeded operation as an idempotent no-op" do
    operation.mark_succeeded!(provider_resource_id: "shipment-1")

    expect(operation.claim!).to be(false)
  end
end
