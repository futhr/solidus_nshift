# frozen_string_literal: true

require "unit_helper"

RSpec.describe SolidusNshift::Configuration do
  it "keeps the fallback cache on the configured clock" do
    now = Time.utc(2026, 8, 17, 10)
    configuration = described_class.new
    allow(configuration).to receive(:rails_cache)
    configuration.clock = -> { now }
    configuration.cache.write("key", "value", expires_in: 10)

    now += 11

    expect(configuration.cache.read("key")).to be_nil
  end
end
