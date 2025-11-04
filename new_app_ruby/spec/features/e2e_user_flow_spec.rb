require 'spec_helper'

RSpec.feature "End-to-End User Flows", type: :feature do
  
  scenario "Complete user registration and login flow" do
    # Visit the home page
    visit '/'
    expect(page).to have_content 'Search'
    
    # Navigate to registration page
    click_link 'Register'
    expect(page).to have_current_path('/register')
    expect(page).to have_content 'Sign Up'
    
    # Fill in registration form
    fill_in 'username', with: 'newuser'
    fill_in 'email', with: 'newuser@example.com'
    fill_in 'password', with: 'SecurePass123'
    fill_in 'password2', with: 'SecurePass123'
    
    # Submit registration
    click_button 'Sign Up'
    
    # Should redirect to login page after successful registration
    expect(page).to have_current_path('/login')
    expect(page).to have_content 'Log In'
    
    # Now login with the newly created user
    fill_in 'username', with: 'newuser'
    fill_in 'password', with: 'SecurePass123'
    click_button 'Log In'
    
    # Should be redirected to search page after successful login
    expect(page).to have_current_path('/api/search?q=')
  end
  
  scenario "User login and logout flow" do
    # Visit login page
    visit '/login'
    expect(page).to have_content 'Log In'
    
    # Login with existing test user
    fill_in 'username', with: 'testuser'
    fill_in 'password', with: 'password123'
    click_button 'Log In'
    
    # Should be redirected to search page
    expect(page).to have_current_path('/api/search?q=')
    
    # Now logout
    visit '/api/logout'
    
    # Should be redirected to login page with flash message
    expect(page).to have_current_path('/login')
    expect(page).to have_content 'Thank you for now'
  end
  
  scenario "User searches for content" do
    # Visit home page
    visit '/'
    
    # Perform a search for MATLAB
    fill_in 'q', with: 'MATLAB'
    click_button 'Search'
    
    # Verify search results are displayed
    expect(page).to have_content 'MATLAB'
  end
  
  scenario "User searches for Python content" do
    # Visit home page
    visit '/'
    
    # Perform a search for Python
    fill_in 'q', with: 'Python'
    click_button 'Search'
    
    # Verify search results are displayed
    expect(page).to have_content 'Python'
  end
  
  scenario "User navigates to about page" do
    # Visit home page
    visit '/'
    
    # Click on About link
    click_link 'About'
    
    # Should be on the about page
    expect(page).to have_current_path('/about')
  end
  
  scenario "User tries to register with invalid data" do
    # Visit registration page
    visit '/register'
    
    # Fill in form with mismatched passwords
    fill_in 'username', with: 'testuser2'
    fill_in 'email', with: 'test2@example.com'
    fill_in 'password', with: 'password123'
    fill_in 'password2', with: 'differentpassword'
    
    # Submit registration
    click_button 'Sign Up'
    
    # Should stay on registration page (indicating validation failed)
    expect(page).to have_current_path('/api/register')
    expect(page).to have_content 'Sign Up'
  end
  
  scenario "User tries to register with existing username" do
    # Visit registration page
    visit '/register'
    
    # Try to register with existing username
    fill_in 'username', with: 'testuser'
    fill_in 'email', with: 'another@example.com'
    fill_in 'password', with: 'password123'
    fill_in 'password2', with: 'password123'
    
    # Submit registration
    click_button 'Sign Up'
    
    # Should stay on registration page with error message
    expect(page).to have_current_path('/api/register')
    expect(page).to have_content(/already taken|username/i)
  end
  
  scenario "User tries to login with invalid credentials" do
    # Visit login page
    visit '/login'
    
    # Try to login with wrong password
    fill_in 'username', with: 'testuser'
    fill_in 'password', with: 'wrongpassword'
    click_button 'Log In'
    
    # Should stay on login page with error message
    expect(page).to have_current_path('/api/login')
    expect(page).to have_content 'Invalid password'
  end
  
  scenario "User tries to login with non-existent username" do
    # Visit login page
    visit '/login'
    
    # Try to login with non-existent user
    fill_in 'username', with: 'nonexistentuser'
    fill_in 'password', with: 'somepassword'
    click_button 'Log In'
    
    # Should stay on login page with error message
    expect(page).to have_current_path('/api/login')
    expect(page).to have_content 'Invalid username'
  end
  
  scenario "User performs empty search" do
    # Visit home page
    visit '/'
    
    # Submit search without entering anything
    click_button 'Search'
    
    # Should remain on the search page (with empty query parameter)
    expect(page).to have_current_path('/?q=')
  end
  
  scenario "User accesses weather page" do
    # Visit weather page
    visit '/weather'
    
    # Should see weather information (with default city Copenhagen)
    expect(page).to have_content(/weather|Weather|Copenhagen/i)
  end
  
  scenario "User accesses weather page with specific city" do
    # Visit weather page with query parameter
    visit '/weather?city=London'
    
    # Should see weather information for London
    expect(page).to have_content(/weather|Weather|London/i)
  end
  
  scenario "Complete authenticated user journey" do
    # 1. Register a new user
    visit '/register'
    fill_in 'username', with: 'journeyuser'
    fill_in 'email', with: 'journey@example.com'
    fill_in 'password', with: 'Journey123'
    fill_in 'password2', with: 'Journey123'
    click_button 'Sign Up'
    
    # 2. Login
    expect(page).to have_current_path('/login')
    fill_in 'username', with: 'journeyuser'
    fill_in 'password', with: 'Journey123'
    click_button 'Log In'
    
    # 3. Perform a search while logged in
    expect(page).to have_current_path('/api/search?q=')
    fill_in 'q', with: 'Ruby'
    click_button 'Search'
    expect(page).to have_content 'Ruby'
    
    # 4. Visit about page
    click_link 'About'
    expect(page).to have_current_path('/about')
    
    # 5. Visit weather page
    visit '/weather'
    expect(page).to have_content(/weather|Weather/i)
    
    # 6. Logout
    visit '/api/logout'
    expect(page).to have_current_path('/login')
  end
end
