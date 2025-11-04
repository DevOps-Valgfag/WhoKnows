ENV['RACK_ENV'] = 'test'

require 'capybara/rspec'
require 'rspec'
require_relative '../app'
require_relative 'support/database_helper'

Capybara.app = Sinatra::Application

RSpec.configure do |config|
  config.include Capybara::DSL

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  
  # Set up test database before all tests
  config.before(:suite) do
    DatabaseHelper.setup_test_database
  end
  
  # Clean up test database after all tests
  config.after(:suite) do
    DatabaseHelper.cleanup_test_database
  end
end