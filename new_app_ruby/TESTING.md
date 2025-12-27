# Testing Guide

This guide explains how to run the test suite locally.

## Prerequisites

- Ruby 3.2+
- Bundler
- Docker (for PostgreSQL)
- Google Chrome (for E2E browser tests)

## Setup

### 1. Install Dependencies

```bash
cd new_app_ruby
bundle install
```

### 2. Configure Test Environment

Create a `.env.test` file in the `new_app_ruby` directory:

```env
SESSION_SECRET=test-secret-key-for-testing-only
DATABASE_URL=postgresql://whoknows:your-secure-password-here@localhost:5432/whoknows_test
```

Adjust the database credentials to match your PostgreSQL setup.

### 3. Start PostgreSQL

Start a PostgreSQL container for testing:

```bash
docker run -d \
  --name whoknows-postgres-test \
  -p 5432:5432 \
  -e POSTGRES_DB=postgres \
  -e POSTGRES_USER=whoknows \
  -e POSTGRES_PASSWORD=your-secure-password-here \
  postgres:17
```

**Note:** The test suite will automatically create the `whoknows_test` database if it doesn't exist.

## Running Tests

```bash
cd new_app_ruby
bundle exec rspec
```

### Run Specific Tests

```bash
# Run a specific test file
bundle exec rspec spec/features/search_spec.rb

# Run a specific test by line number
bundle exec rspec spec/features/register_spec.rb:4
```

## Test Suite Overview

The test suite has two types of tests:

### Fast Tests (rack_test driver)
These run without a browser and are very fast.

| Test File | Description |
|-----------|-------------|
| `spec/features/search_spec.rb` | Tests search functionality |
| `spec/features/register_spec.rb` | Tests user registration |
| `spec/features/auth_spec.rb` | Tests login/logout flows |
| `spec/unit/security_spec.rb` | Tests password hashing helpers |

### E2E Browser Tests (Selenium + headless Chrome)
These run in a real headless Chrome browser.

| Test File | Description |
|-----------|-------------|
| `spec/e2e/search_e2e_spec.rb` | Browser tests for search |
| `spec/e2e/auth_e2e_spec.rb` | Browser tests for authentication |
| `spec/e2e/pages_e2e_spec.rb` | Browser tests for page navigation |

### Running Tests Separately

```bash
# Run only fast tests (unit + features)
bundle exec rspec spec/unit spec/features

# Run only E2E browser tests
bundle exec rspec spec/e2e

# Run all tests
bundle exec rspec
```

## How It Works

### Test Infrastructure

The test suite (`spec/spec_helper.rb`) automatically:

1. Loads environment variables from `.env.test`
2. Creates the test database (`whoknows_test`) if it doesn't exist
3. Sets up the database schema (tables)
4. Seeds test data (MATLAB page for search tests)
5. Cleans up user data between tests

### E2E Browser Tests

E2E tests use **Capybara with Selenium** and headless Chrome:

- Tests marked with `js: true` run in a real browser
- Capybara starts a Puma server automatically
- Chrome runs in headless mode (no visible window)
- Tests can interact with JavaScript-rendered content

```ruby
# Example E2E test (runs in browser)
RSpec.feature 'Search E2E', type: :feature, js: true do
  scenario 'can search and see results' do
    visit '/'
    fill_in 'q', with: 'MATLAB'
    click_button 'search-button'
    expect(page).to have_css('.search-result')
  end
end
```

### Fast Feature Tests

Feature tests without `js: true` use rack_test driver:

- No real browser needed
- Much faster execution
- Cannot test JavaScript functionality

```ruby
# Example fast test (no browser)
RSpec.feature 'Search', type: :feature do
  scenario 'searching shows results' do
    visit '/?q=MATLAB&language=en'
    expect(page).to have_css('.search-result')
  end
end
```

## Troubleshooting

### Connection Refused

If you see `PG::ConnectionBad: connection refused`:

1. Ensure PostgreSQL is running: `docker ps`
2. Check the container logs: `docker logs whoknows-postgres-test`
3. Verify your `DATABASE_URL` in `.env.test` matches your container settings

### Database Already Exists

This is fine - the test suite handles this gracefully.

### Stop and Remove Test Container

```bash
docker stop whoknows-postgres-test
docker rm whoknows-postgres-test
```

## CI/CD

Tests run automatically on GitHub Actions when pushing to `dev` or `main` branches.

The workflow (`.github/workflows/ruby-tests.yml`):

1. Sets up PostgreSQL service container
2. Installs Ruby and dependencies
3. Installs Chrome for E2E tests
4. Runs unit and feature tests
5. Runs E2E browser tests

Both test types must pass for the workflow to succeed.
