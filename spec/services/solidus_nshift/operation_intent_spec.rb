# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::OperationIntent do
  let(:data) { create_nshift_shipment }
  let(:fulfillment) do
    SolidusNshift::Fulfillment.create!(
      shipment: data[:shipment], connection: data[:connection], rate_selection: data[:selection],
      merchant_reference: SolidusNshift::Reference.for(data[:shipment])
    )
  end

  def intent(fingerprint)
    described_class.new(fulfillment:, kind: "delivery_booking", fingerprint:).call
  end

  it "retains a rejected attempt and creates a revision for corrected data" do
    first = intent("a" * 64)
    first.mark_rejected!(SolidusNshift::ValidationError.new("invalid receiver"))

    second = intent("b" * 64)

    expect(second).to have_attributes(revision: 2, status: "pending", request_fingerprint: "b" * 64)
    expect(first.reload).to have_attributes(revision: 1, status: "rejected", request_fingerprint: "a" * 64)
  end

  it "refuses a changed payload while the current outcome is ambiguous" do
    operation = intent("a" * 64)
    operation.mark_unknown!(SolidusNshift::TimeoutUnknownOutcome.new("timed out"))

    expect { intent("b" * 64) }
      .to raise_error(SolidusNshift::ShipmentConflictError, /conflicts/)
    expect(fulfillment.operations.count).to eq(1)
  end
end
