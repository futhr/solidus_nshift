# frozen_string_literal: true

module SolidusNshift
  module Checkout
    Session = Data.define(:id, :expires_at, :raw_reference)
  end
end
