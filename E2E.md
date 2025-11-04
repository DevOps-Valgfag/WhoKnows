# End-to-End (E2E) Testing Documentation

This document outlines the end-to-end tests for the WhoKnows application. These tests are designed to simulate real user scenarios and ensure the application behaves as expected from the user's perspective.

## Test Suite

The E2E tests are written using RSpec and Capybara with a comprehensive test database setup.

## Running the Tests

To run all E2E tests:

```bash
cd new_app_ruby
bundle exec rspec spec/features/
```

To run specific test files:

```bash
bundle exec rspec spec/features/search_spec.rb
bundle exec rspec spec/features/e2e_user_flow_spec.rb
```

## Test Database Setup

The E2E tests use a test database that is automatically set up before the test suite runs and cleaned up afterwards. The database helper is located in `spec/support/database_helper.rb` and:

- Creates a fresh SQLite database for testing
- Seeds it with sample data (test users and pages)
- Automatically cleans up after all tests complete

### Comprehensive User Flow Tests

The complete E2E test suite (`spec/features/e2e_user_flow_spec.rb`) includes:

#### 1. User Registration Flow
*   **Description**: Tests the complete user registration process
*   **Steps**:
    1.  Navigate to the registration page
    2.  Fill in the registration form with valid data
    3.  Submit the form
    4.  Verify successful registration and redirect to login page

#### 2. User Login and Logout Flow
*   **Description**: Tests user authentication and session management
*   **Steps**:
    1.  Navigate to the login page
    2.  Login with valid credentials
    3.  Verify successful login
    4.  Logout
    5.  Verify logout and redirect to login page with confirmation message

#### 3. Search Functionality
*   **Description**: Tests the search feature with various queries
*   **Scenarios**:
    - Search for "MATLAB" and verify results
    - Search for "Python" and verify results
    - Perform empty search and verify behavior

#### 4. Validation and Error Handling
*   **Description**: Tests form validation and error scenarios
*   **Scenarios**:
    - Try to register with mismatched passwords
    - Try to register with an existing username
    - Try to login with invalid credentials
    - Try to login with non-existent username

#### 5. Navigation Tests
*   **Description**: Tests navigation between different pages
*   **Scenarios**:
    - Navigate to About page
    - Navigate to Weather page
    - Navigate to Weather page with specific city parameter

#### 6. Complete Authenticated User Journey
*   **Description**: Tests a complete end-to-end user journey
*   **Steps**:
    1.  Register a new user account
    2.  Login with the newly created account
    3.  Perform a search while authenticated
    4.  Navigate to the About page
    5.  Visit the Weather page
    6.  Logout

### Basic Feature Tests

The basic feature test suite (`spec/features/search_spec.rb`) includes:

#### 1. Visit the Search Page
*   **Description**: Ensures that the main search page is accessible
*   **Steps**:
    1.  Navigate to the root URL (`/`)
    2.  Verify that the page content includes "Search"

#### 2. Perform a Search
*   **Description**: Simulates a user performing a search
*   **Steps**:
    1.  Navigate to the root URL (`/`)
    2.  Fill in the search input field with "matlab"
    3.  Click the "Search" button
    4.  Verify that search results include "MATLAB"

#### 3. Navigate to Login Page
*   **Description**: Tests navigation to the login page
*   **Steps**:
    1.  Navigate to the root URL (`/`)
    2.  Click the "Log in" link
    3.  Verify that the current path is `/login`

#### 4. Navigate to Register Page
*   **Description**: Tests navigation to the registration page
*   **Steps**:
    1.  Navigate to the root URL (`/`)
    2.  Click the "Register" link
    3.  Verify that the current path is `/register`

#### 5. Navigate to About Page
*   **Description**: Tests navigation to the about page
*   **Steps**:
    1.  Navigate to the root URL (`/`)
    2.  Click the "About" link
    3.  Verify that the current path is `/about`

## Test Coverage Summary

The E2E test suite covers:
- ✅ User registration with validation
- ✅ User authentication (login/logout)
- ✅ Search functionality
- ✅ Error handling and validation
- ✅ Navigation between pages
- ✅ Session management
- ✅ Complete user journeys
- ✅ Weather feature access

## Notes

- The weather API tests expect network connectivity issues in test environment and handle them gracefully
- All tests use Capybara for browser simulation
- Test database is isolated from production database
- Tests are idempotent and can be run multiple times
