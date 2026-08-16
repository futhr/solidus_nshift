# frozen_string_literal: true

require "rails/generators"

module SolidusNshift
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      class_option :auto_run_migrations, type: :boolean, default: false

      def copy_initializer
        template "solidus_nshift.rb", "config/initializers/solidus_nshift.rb"
      end

      def copy_migrations
        rake "solidus_nshift:install:migrations"
      end

      def mount_engine
        route 'mount SolidusNshift::Engine => "/solidus_nshift", as: :solidus_nshift'
      end

      def run_migrations
        rake "db:migrate" if options[:auto_run_migrations]
      end
    end
  end
end
