ENV['RACK_ENV'] = 'test'

require 'capybara/rspec'
require 'rspec'
require_relative '../app'
require_relative './support/database_helpers'

Capybara.app = Sinatra::Application

RSpec.configure do |config|
  config.include Capybara::DSL
  config.include DatabaseHelpers

  config.before(:each) do
    clear_users
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end