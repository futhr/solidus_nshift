# frozen_string_literal: true

module SolidusNshift
  class Configuration
    attr_accessor :cache, :clock, :logger, :sleeper, :transport_factory,
      :rate_cache_ttl, :parcel_builder, :book_shipment_job, :sync_tracking_job

    def initialize
      @clock = -> { Time.now }
      @cache = MemoryCache.new(clock: @clock)
      @logger = -> { defined?(Rails) ? Rails.logger : nil }
      @sleeper = ->(seconds) { sleep(seconds) }
      @transport_factory = -> { Http::NetHttpTransport.new }
      @rate_cache_ttl = 300
      @parcel_builder = ->(shipment) { Solidus::PackageSerializer.default_parcels(shipment) }
      @book_shipment_job = -> { SolidusNshift::BookShipmentJob }
      @sync_tracking_job = -> { SolidusNshift::SyncTrackingJob }
    end
  end
end
