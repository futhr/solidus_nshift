# frozen_string_literal: true

module SolidusNshift
  class MemoryCache
    Entry = Data.define(:value, :expires_at)

    def initialize(clock: -> { Time.now }, max_entries: 1_000)
      @clock = clock
      @max_entries = Integer(max_entries)
      raise ArgumentError, "cache entry limit must be positive" unless @max_entries.positive?
      @entries = {}
      @mutex = Mutex.new
    end

    def read(key)
      @mutex.synchronize do
        entry = @entries[key]
        return unless entry
        if entry.expires_at && entry.expires_at <= @clock.call
          @entries.delete(key)
          return
        end

        entry.value
      end
    end

    def write(key, value, expires_in: nil)
      expires_at = expires_in && (@clock.call + expires_in)
      @mutex.synchronize do
        @entries.delete(key)
        if @entries.size >= @max_entries
          now = @clock.call
          @entries.delete_if { |_key, entry| entry.expires_at && entry.expires_at <= now }
          @entries.shift while @entries.size >= @max_entries
        end
        @entries[key] = Entry.new(value:, expires_at:)
      end
      value
    end

    def delete(key)
      @mutex.synchronize { @entries.delete(key) }
    end

    def fetch(key, expires_in: nil)
      cached = read(key)
      return cached unless cached.nil?

      value = yield
      write(key, value, expires_in:)
    end

    def clear
      @mutex.synchronize { @entries.clear }
    end
  end
end
