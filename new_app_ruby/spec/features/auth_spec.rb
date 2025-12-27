require 'spec_helper'

RSpec.feature 'Authentication', type: :feature do
  let(:username) { "testuser_#{Time.now.to_i}" }
  let(:email) { "#{username}@example.com" }
  let(:password) { 'Password123!' }

  before do
    # Create a test user with hashed password
    hashed_password = BCrypt::Password.create(password)
    DB[:users].insert(
      username: username,
      email: email,
      password: hashed_password,
      must_change_password: 0
    )
  end

  scenario 'user can log in with valid credentials' do
    visit '/login'

    fill_in 'username', with: username
    fill_in 'password', with: password
    click_button 'Log In'

    # After login, user is redirected to search page
    expect(page).to have_current_path('/api/search', ignore_query: true)
  end

  scenario 'user sees error with invalid password' do
    visit '/login'

    fill_in 'username', with: username
    fill_in 'password', with: 'wrongpassword'
    click_button 'Log In'

    # Should stay on login page with error
    expect(page).to have_content('Invalid password')
  end

  scenario 'user sees error with invalid username' do
    visit '/login'

    fill_in 'username', with: 'nonexistent_user'
    fill_in 'password', with: password
    click_button 'Log In'

    expect(page).to have_content('Invalid username')
  end

  scenario 'logged-in user can log out' do
    # First log in
    visit '/login'
    fill_in 'username', with: username
    fill_in 'password', with: password
    click_button 'Log In'

    # Then log out
    visit '/api/logout'

    # Should be redirected to login page
    expect(page).to have_current_path('/login')
    expect(page).to have_content('Thank you for now')
  end
end
