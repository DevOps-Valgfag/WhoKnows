# End-to-End (E2E) Testing Documentation

This document outlines the end-to-end tests for the WhoKnows application. These tests are designed to simulate real user scenarios and ensure the application behaves as expected from the user's perspective.

## Test Suite

The E2E tests are written using RSpec and Capybara.

### Search Feature

The search feature is a critical part of the application. The following scenarios are tested:

1.  **Visit the Search Page**:
    *   **Description**: This test ensures that the main search page is accessible to users.
    *   **Steps**:
        1.  Navigate to the root URL (`/`).
        2.  Verify that the page content includes "Search".
    *   **File**: `spec/features/search_spec.rb`

2.  **Perform a Search**:
    *   **Description**: This test simulates a user performing a search and verifies that the search results are displayed.
    *   **Steps**:
        1.  Navigate to the root URL (`/`).
        2.  Fill in the search input field with "matlab".
        3.  Click the "Search" button.
        4.  Verify that the page content includes "MATLAB", indicating that the search was successful.
    *   **File**: `spec/features/search_spec.rb`

### Navigation

1.  **Navigate to Login Page**:
    *   **Description**: This test ensures that a user can navigate to the login page from the home page.
    *   **Steps**:
        1.  Navigate to the root URL (`/`).
        2.  Click the "Log in" link.
        3.  Verify that the current path is `/login`.
    *   **File**: `spec/features/search_spec.rb`
