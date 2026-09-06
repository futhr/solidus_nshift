# frozen_string_literal: true

require "unit_helper"

RSpec.describe SolidusNshift::MemoryCache do
  it "expires values using the injected clock" do
    now = Time.utc(2026, 8, 16, 10)
    cache = described_class.new(clock: -> { now })
    cache.write("key", "value", expires_in: 10)

    expect(cache.read("key")).to eq("value")
    now += 11
    expect(cache.read("key")).to be_nil
  end

  it "computes a missing value once per sequential fetch" do
    calls = 0
    cache = described_class.new

    2.times { cache.fetch("key") { calls += 1 } }

    expect(calls).to eq(1)
  end

  it "bounds memory even when expired keys are never read again" do
    now = Time.utc(2026, 9, 6)
    cache = described_class.new(clock: -> { now }, max_entries: 2)
    cache.write("live", "keep", expires_in: 60)
    cache.write("expired", "discard", expires_in: 1)
    now += 2
    cache.write("new", "new value")

    expect(cache.read("live")).to eq("keep")
    expect(cache.read("expired")).to be_nil
    cache.write("newer", "newer value")
    expect(cache.read("live")).to be_nil
    expect(cache.read("new")).to eq("new value")
  end
end
