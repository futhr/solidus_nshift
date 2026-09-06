# frozen_string_literal: true

require "unit_helper"

RSpec.describe SolidusNshift::Instrumentation do
  it "reports an error class without publishing exception objects or messages" do
    payloads = []
    subscriber = ->(event) { payloads << event.payload }

    ActiveSupport::Notifications.subscribed(subscriber, "solidus_nshift.request") do
      expect do
        described_class.request(operation: "booking") { raise "private@example.test" }
      end.to raise_error(RuntimeError, "private@example.test")
    end

    expect(payloads).to eq([{operation: "booking", error_class: "RuntimeError"}])
  end

  it "preserves a successful provider result when an instrumentation subscriber fails" do
    subscriber = ->(_event) { raise "subscriber failed" }

    ActiveSupport::Notifications.subscribed(subscriber, "solidus_nshift.request") do
      expect(described_class.request(operation: "booking") { "shipment-1" }).to eq("shipment-1")
    end
  end
end
