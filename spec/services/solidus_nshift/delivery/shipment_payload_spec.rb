# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::Delivery::ShipmentPayload do
  it "maps Solidus parties, parcels, service, and a selected pickup point" do
    data = create_nshift_shipment(pickup: true)
    fulfillment = SolidusNshift::Fulfillment.create!(
      shipment: data[:shipment],
      connection: data[:connection],
      rate_selection: data[:selection],
      merchant_reference: SolidusNshift::Reference.for(data[:shipment])
    )

    payload = described_class.new(fulfillment:).call

    expect(payload).to include(
      developerId: "solidus-nshift-tests",
      test: true,
      sender: {quickId: "1"},
      service: {id: "P19"},
      orderNo: fulfillment.merchant_reference
    )
    expect(payload[:receiver]).to include(name: data[:order].ship_address.name, country: "SE")
    expect(payload[:agent]).to include(quickId: "SE-10001", name: "Synthetic Market")
    expect(payload.dig(:parcels, 0, :weight).value).to eq(BigDecimal("1.5"))
    expect(JSON.generate(payload)).to include('"weight":1.5')
  end

  it "allows a merchant parcel builder to produce multiple parcels" do
    data = create_nshift_shipment
    fulfillment = SolidusNshift::Fulfillment.create!(
      shipment: data[:shipment], connection: data[:connection], rate_selection: data[:selection],
      merchant_reference: SolidusNshift::Reference.for(data[:shipment])
    )
    SolidusNshift.configuration.parcel_builder = lambda do |_shipment|
      [{weight: "1.2", copies: 1}, {weight: "2.3", copies: 2, contents: "Books"}]
    end

    payload = described_class.new(fulfillment:).call

    expect(payload[:parcels].map { |parcel| parcel[:weight].value }).to eq([BigDecimal("1.2"), BigDecimal("2.3")])
    expect(payload.dig(:parcels, 1, :copies)).to eq(2)
  end
end
