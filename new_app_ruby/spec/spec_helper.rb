# spec/spec_helper.rb
ENV['RACK_ENV'] = 'test'

require 'rspec'
require 'rack/test'
require 'capybara/rspec'
require 'selenium-webdriver' # because they mentioned it
require_relative '../app'    # loads app.rb (Sinatra app)

Capybara.app = Sinatra::Application

# Default: no real browser, just fast rack_test
Capybara.default_driver = :rack_test

# If you later want JS tests with a real browser:
Capybara.javascript_driver = :selenium_chrome_headless

RSpec.configure do |config|
  # So we can use `get`, `post`, etc. if we want rack-style tests
  config.include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.order = :random
  Kernel.srand config.seed
end
