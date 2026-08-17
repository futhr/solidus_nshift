# frozen_string_literal: true

module SolidusNshift
  module Checkout
    Session = Data.define(:id, :expires_at, :checkout_configuration_id)
  end
end
