# frozen_string_literal: true

module SolidusNshift
  class JobEnqueuer
    def self.call(job_class:, arguments:, operation:, metadata: {})
      result = job_class.perform_later(*arguments)
      unless result
        error = ActiveJob::EnqueueError.new("job enqueue was aborted")
        report(error, operation:, metadata:)
        return false
      end

      true
    rescue => error
      report(error, operation:, metadata:)
      false
    end

    def self.report(error, operation:, metadata:)
      payload = metadata.merge(operation:, error_class: error.class.name)
      ActiveSupport::Notifications.instrument("solidus_nshift.enqueue_failed", payload)
      SolidusNshift.configuration.logger.call&.warn(
        payload.merge(provider: "nshift", result: "failed")
      )
    rescue
      nil
    end
    private_class_method :report
  end
end
