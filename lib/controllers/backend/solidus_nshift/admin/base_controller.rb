# frozen_string_literal: true

module SolidusNshift
  module Admin
    class BaseController < Spree::Admin::BaseController
      helper SolidusNshift::Engine.routes.url_helpers
    end
  end
end
