# frozen_string_literal: true

module SolidusNshift
  class MemoryCache
    Entry = Data.define(:value, :expires_at)

    def initialize(clock: -> { Time.now })
      @clock = clock
      @entries = {}
      @mutex = Mutex.new
    end

    def read(key)
      @mutex.synchronize do
        entry = @entries[key]
        return unless entry
        return @entries.delete(key) && nil if entry.expires_at && entry.expires_at <= @clock.call

        entry.value
      end
    end

    def write(key, value, expires_in: nil)
      expires_at = expires_in && (@clock.call + expires_in)
      @mutex.synchronize { @entries[key] = Entry.new(value:, expires_at:) }
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
