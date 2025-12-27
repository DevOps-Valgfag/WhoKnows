# spec/spec_helper.rb
ENV['RACK_ENV'] = 'test'

require 'dotenv'
# Load test-specific environment variables
Dotenv.load('.env.test')

require 'rspec'
require 'rack/test'
require 'capybara/rspec'
require 'selenium-webdriver'
require 'sequel'
require 'pg'

# Create test database if it doesn't exist
def setup_test_database!
  db_url = ENV.fetch('DATABASE_URL')
  # Parse the database name from URL
  db_name = db_url.split('/').last
  base_url = db_url.sub(/\/[^\/]+$/, '/postgres')

  begin
    # Connect to postgres database to create test db
    admin_db = Sequel.connect(base_url)

    # Check if test database exists
    exists = admin_db.fetch("SELECT 1 FROM pg_database WHERE datname = ?", db_name).first

    unless exists
      admin_db.run("CREATE DATABASE #{db_name}")
      puts "Created test database: #{db_name}"
    end

    admin_db.disconnect
  rescue Sequel::DatabaseConnectionError => e
    puts "Warning: Could not connect to create test database: #{e.message}"
    puts "Make sure PostgreSQL is running and accessible."
    raise
  end
end

def setup_test_schema!(db)
  # Create tables if they don't exist
  db.run <<-SQL
    CREATE TABLE IF NOT EXISTS pages (
      title TEXT PRIMARY KEY,
      url TEXT NOT NULL UNIQUE,
      language TEXT NOT NULL CHECK(language IN ('en', 'da')) DEFAULT 'en',
      last_updated TIMESTAMP,
      content TEXT NOT NULL
    );
  SQL

  db.run <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      email TEXT NOT NULL UNIQUE,
      password TEXT NOT NULL,
      must_change_password INTEGER DEFAULT 1
    );
  SQL
end

def seed_test_data!(db)
  # Insert test data if not exists
  unless db[:pages].where(title: 'MATLAB').first
    db[:pages].insert(
      title: 'MATLAB',
      url: 'http://web.archive.org/web/20090110165251/http://en.wikipedia.org:80/wiki/Matlab',
      language: 'en',
      last_updated: Time.new(2009, 1, 10),
      content: 'MATLAB is a numerical computing environment and programming language used for matrix computations, algorithm development, data analysis and visualization.'
    )
  end
end

# Setup test database before loading app
setup_test_database!

require_relative '../app'    # loads app.rb (Sinatra app)

# Setup schema and seed data
setup_test_schema!(DB)
seed_test_data!(DB)

Capybara.app = Sinatra::Application

# Default: no real browser, just fast rack_test
Capybara.default_driver = :rack_test

# Register headless Chrome for E2E browser tests
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1920,1080')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

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

  # Clean up database between tests
  config.before(:each) do
    DB[:users].delete
  end

  config.order = :random
  Kernel.srand config.seed
end
