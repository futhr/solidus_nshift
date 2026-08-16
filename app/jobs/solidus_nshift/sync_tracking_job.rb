# frozen_string_literal: true

module SolidusNshift
  class SyncTrackingJob < ActiveJob::Base
    queue_as :default

    discard_on ActiveRecord::RecordNotFound
    retry_on RateLimitError, wait: 1.minute, attempts: 3
    retry_on TransportError, wait: :polynomially_longer, attempts: 5
    retry_on ProviderUnavailableError, wait: :polynomially_longer, attempts: 5

    def perform(fulfillment_id)
      SyncTracking.new(fulfillment: Fulfillment.find(fulfillment_id)).call
    end
  end
end
