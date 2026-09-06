# frozen_string_literal: true

module SolidusNshift
  module Instrumentation
    def self.request(**metadata)
      yield
    rescue => error
      raise
    ensure
      # Block instrumentation adds the exception object and its message to the
      # event payload. Provider errors may contain credentials or customer data.
      publish(metadata.merge(error_class: error&.class&.name))
    end

    def self.publish(metadata)
      ActiveSupport::Notifications.instrument("solidus_nshift.request", metadata)
    rescue
      # A failing subscriber must not change the outcome of a provider mutation.
      nil
    end
    private_class_method :publish
  end
end
