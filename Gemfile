# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

solidus_branch = ENV.fetch("SOLIDUS_BRANCH", "v4.7")
gem "solidus", github: "solidusio/solidus", branch: solidus_branch

rails_series = ENV.fetch("RAILS_VERSION", "7.2")
rails_requirement = (rails_series.count(".") == 1) ? "~> #{rails_series}.0" : "~> #{rails_series}"
rails_requirements = [rails_requirement]
rails_requirements << ">= 7.2.3.2" if rails_series == "7.2"
gem "rails", *rails_requirements

case ENV.fetch("DB", "sqlite")
when "postgresql" then gem "pg"
when "mysql" then gem "mysql2"
else
  gem "sqlite3", "~> 2.0"
end

gem "csv" if RUBY_VERSION >= "3.4"

gemspec
