# frozen_string_literal: true

require "solidus_nshift/version"
require "solidus_nshift/errors"
require "solidus_nshift/memory_cache"
require "solidus_nshift/json_decimal"
require "solidus_nshift/units"
require "solidus_nshift/http/net_http_transport"
require "solidus_nshift/http/response_handling"
require "solidus_nshift/oauth/token"
require "solidus_nshift/oauth/token_provider"
require "solidus_nshift/checkout/session"
require "solidus_nshift/checkout/pickup_point"
require "solidus_nshift/checkout/shipping_option"
require "solidus_nshift/checkout/option_normalizer"
require "solidus_nshift/checkout/client"
require "solidus_nshift/checkout/package_request"
require "solidus_nshift/delivery/document"
require "solidus_nshift/delivery/shipment"
require "solidus_nshift/delivery/client"
require "solidus_nshift/shipment_data/event"
require "solidus_nshift/shipment_data/event_normalizer"
require "solidus_nshift/shipment_data/client"
require "solidus_nshift/configuration"

module SolidusNshift
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end

require "solidus_nshift/engine"
