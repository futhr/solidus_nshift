# frozen_string_literal: true

module SolidusNshift
  class CancelFulfillmentJob < ActiveJob::Base
    queue_as :default

    discard_on ActiveRecord::RecordNotFound

    def perform(fulfillment_id)
      CancelFulfillment.new(fulfillment: Fulfillment.find(fulfillment_id)).call
    end
  end
end
