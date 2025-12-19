# Testing Guide

This guide explains how to run the test suite locally.

## Prerequisites

- Ruby 3.2+
- Bundler
- Docker (for PostgreSQL)

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

| Test File | Description |
|-----------|-------------|
| `spec/features/search_spec.rb` | Tests search functionality |
| `spec/features/register_spec.rb` | Tests user registration |
| `spec/helpers/security_spec.rb` | Tests password hashing helpers |

## How It Works

The test suite (`spec/spec_helper.rb`) automatically:

1. Loads environment variables from `.env.test`
2. Creates the test database (`whoknows_test`) if it doesn't exist
3. Sets up the database schema (tables)
4. Seeds test data (MATLAB page for search tests)
5. Cleans up user data between tests

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

Tests run automatically on GitHub Actions when pushing to `dev`, `main`, or `feature/testing-setup` branches. The CI workflow uses its own PostgreSQL service container.
