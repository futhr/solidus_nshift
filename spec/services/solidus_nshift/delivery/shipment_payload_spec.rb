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

    expect(payload[:printConfig]).to eq(target1Media: "laser-a4", target1Type: "pdf")
    expect(payload[:shipment]).to include(
      developerId: "solidus-nshift-tests",
      test: true,
      sender: {
        quickId: "1",
        name: "Synthetic Merchant",
        address1: "Examplegatan 1",
        zipcode: "111 22",
        city: "Stockholm",
        country: "SE",
        phone: "+46800000000",
        email: "shipping@example.test"
      },
      service: {id: "P19"},
      orderNo: fulfillment.merchant_reference
    )
    expect(payload.dig(:shipment, :receiver)).to include(name: data[:order].ship_address.name, country: "SE")
    expect(payload.dig(:shipment, :agent)).to include(quickId: "SE-10001", name: "Synthetic Market")
    expect(payload.dig(:shipment, :parcels, 0, :weight).value).to eq(BigDecimal("1.5"))
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

    expect(payload.dig(:shipment, :parcels).map { |parcel| parcel[:weight].value })
      .to eq([BigDecimal("1.2"), BigDecimal("2.3")])
    expect(payload.dig(:shipment, :parcels, 1, :copies)).to eq(2)
  end

  it "converts the calculator's configured weight unit to Delivery kilograms" do
    data = create_nshift_shipment
    data[:calculator].update!(preferred_weight_unit: "g")
    fulfillment = SolidusNshift::Fulfillment.create!(
      shipment: data[:shipment], connection: data[:connection], rate_selection: data[:selection],
      merchant_reference: SolidusNshift::Reference.for(data[:shipment])
    )

    payload = described_class.new(fulfillment:).call

    expect(payload.dig(:shipment, :parcels, 0, :weight).value).to eq(BigDecimal("0.0015"))
  end

  it "rejects non-positive parcel weights and copies" do
    data = create_nshift_shipment
    fulfillment = SolidusNshift::Fulfillment.create!(
      shipment: data[:shipment], connection: data[:connection], rate_selection: data[:selection],
      merchant_reference: SolidusNshift::Reference.for(data[:shipment])
    )

    [{weight: 0, copies: 1}, {weight: 1, copies: 0}, {weight: 1, copies: 1.5}].each do |parcel|
      SolidusNshift.configuration.parcel_builder = ->(_shipment) { [parcel] }
      expect { described_class.new(fulfillment:).call }.to raise_error(SolidusNshift::ValidationError)
    end
  end

  it "rejects a parcel builder that returns a non-array container" do
    data = create_nshift_shipment
    fulfillment = SolidusNshift::Fulfillment.create!(
      shipment: data[:shipment], connection: data[:connection], rate_selection: data[:selection],
      merchant_reference: SolidusNshift::Reference.for(data[:shipment])
    )
    SolidusNshift.configuration.parcel_builder = ->(_shipment) { {weight: 1} }

    expect { described_class.new(fulfillment:).call }
      .to raise_error(SolidusNshift::ValidationError, /non-empty array/)
  end

  it "rejects a receiver missing fields required by Delivery" do
    data = create_nshift_shipment
    fulfillment = SolidusNshift::Fulfillment.create!(
      shipment: data[:shipment], connection: data[:connection], rate_selection: data[:selection],
      merchant_reference: SolidusNshift::Reference.for(data[:shipment])
    )
    address = fulfillment.shipment.order.ship_address
    address.city = ""
    allow(fulfillment.shipment.order).to receive(:ship_address).and_return(address)

    expect { described_class.new(fulfillment:).call }
      .to raise_error(SolidusNshift::ValidationError, /receiver name, city, and country/)
  end
end
