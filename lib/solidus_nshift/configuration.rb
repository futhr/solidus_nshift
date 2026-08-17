# frozen_string_literal: true

module SolidusNshift
  class Configuration
    attr_accessor :clock, :logger, :sleeper, :transport_factory,
      :rate_cache_ttl, :parcel_builder, :book_shipment_job, :sync_tracking_job
    attr_writer :cache

    def initialize
      @clock = -> { Time.now }
      @cache = nil
      @fallback_cache = MemoryCache.new(clock: -> { @clock.call })
      @logger = -> { defined?(Rails) ? Rails.logger : nil }
      @sleeper = ->(seconds) { sleep(seconds) }
      @transport_factory = -> { Http::NetHttpTransport.new }
      @rate_cache_ttl = 300
      @parcel_builder = lambda do |shipment, weight_unit:|
        Solidus::PackageSerializer.default_parcels(shipment, weight_unit:)
      end
      @book_shipment_job = -> { SolidusNshift::BookShipmentJob }
      @sync_tracking_job = -> { SolidusNshift::SyncTrackingJob }
    end

    def cache
      @cache || rails_cache || @fallback_cache
    end

    private

    def rails_cache
      Rails.cache if defined?(Rails) && Rails.respond_to?(:application) && Rails.application
    end
  end
end
