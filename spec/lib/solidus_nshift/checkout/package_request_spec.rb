# frozen_string_literal: true

require "unit_helper"

RSpec.describe SolidusNshift::Checkout::PackageRequestBuilder do
  subject(:request) { build_request }

  let(:attributes) do
    {
      receiver: {postal_code: "120 30", country_code: "se"},
      items: [
        {quantity: 2, weight: "500", length: "20", width: "10", height: "5"}
      ],
      currency: "sek",
      locale: "sv",
      cart_price: "199.95",
      weight_unit: "g",
      dimension_unit: "cm",
      context: {connection_id: 7, shipment_id: 42}
    }
  end

  def build_request
    described_class.new(**attributes).call
  end

  it "builds a Checkout v2 payload with exact JSON numbers" do
    expect(request.payload).to include(currencyCode: "SEK", languageCode: "sv")
    expect(request.payload[:totalWeightKg].value).to eq(BigDecimal("1"))
    expect(request.payload.dig(:packages, 0, :volumeCm3).value).to eq(BigDecimal("2000"))

    json = JSON.generate(request.payload)
    expect(json).to include('"totalWeightKg":1.0')
    expect(json).not_to include('"totalWeightKg":"1.0"')
  end

  it "sends null volume if any item dimension is unavailable" do
    attributes[:items][0][:height] = nil

    expect(request.payload.dig(:packages, 0, :volumeCm3)).to be_nil
  end

  it "changes the digest for address, contents, or connection changes" do
    original = build_request.context_digest

    attributes[:receiver][:postal_code] = "411 01"
    expect(build_request.context_digest).not_to eq(original)

    attributes[:receiver][:postal_code] = "120 30"
    attributes[:items][0][:quantity] = 3
    expect(build_request.context_digest).not_to eq(original)

    attributes[:items][0][:quantity] = 2
    attributes[:context][:connection_id] = 8
    expect(build_request.context_digest).not_to eq(original)
  end

  it "rejects malformed receiver, currency, locale, and price data" do
    invalid = attributes.merge(receiver: {postal_code: "", country_code: "SWE"})
    expect { described_class.new(**invalid) }.to raise_error(SolidusNshift::ValidationError)

    expect { described_class.new(**attributes.merge(currency: "kr")) }.to raise_error(SolidusNshift::ValidationError)
    expect { described_class.new(**attributes.merge(locale: "sv-SE")) }.to raise_error(SolidusNshift::ValidationError)
    expect { described_class.new(**attributes.merge(cart_price: "-1")) }.to raise_error(SolidusNshift::ValidationError)
  end
end
