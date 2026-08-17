# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::JobEnqueuer do
  let(:logger) { instance_double(ActiveSupport::Logger, warn: nil) }
  let(:job_class) { class_double(SolidusNshift::BookShipmentJob) }

  before do
    SolidusNshift.configuration.logger = -> { logger }
  end

  it "reports raised enqueue failures without exposing job arguments" do
    allow(job_class).to receive(:perform_later).and_raise(ActiveJob::EnqueueError, "queue unavailable")
    payloads = []

    result = ActiveSupport::Notifications.subscribed(
      ->(*args) { payloads << ActiveSupport::Notifications::Event.new(*args).payload },
      "solidus_nshift.enqueue_failed"
    ) do
      described_class.call(
        job_class:,
        arguments: [123, "sensitive argument"],
        operation: "book_shipment",
        metadata: {fulfillment_id: 456}
      )
    end

    expect(result).to be(false)
    expect(payloads).to contain_exactly(
      operation: "book_shipment", fulfillment_id: 456, error_class: "ActiveJob::EnqueueError"
    )
    expect(payloads.first.to_s).not_to include("sensitive argument")
    expect(logger).to have_received(:warn).with(hash_including(result: "failed", provider: "nshift"))
  end

  it "reports an enqueue callback that aborts without raising" do
    allow(job_class).to receive(:perform_later).and_return(false)

    expect(described_class.call(job_class:, arguments: [123], operation: "book_shipment")).to be(false)
    expect(logger).to have_received(:warn).with(hash_including(error_class: "ActiveJob::EnqueueError"))
  end
end
