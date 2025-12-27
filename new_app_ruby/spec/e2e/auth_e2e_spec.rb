require 'spec_helper'

RSpec.feature 'Authentication E2E', type: :feature, js: true do
  scenario 'can register a new user in browser' do
    username = "e2euser_#{Time.now.to_i}"
    email = "#{username}@example.com"
    password = 'Password123!'

    visit '/register'

    fill_in 'username', with: username
    fill_in 'email', with: email
    fill_in 'password', with: password
    fill_in 'password2', with: password
    click_button 'Sign Up'

    # Should redirect to homepage after registration
    expect(page).to have_current_path('/', ignore_query: true)
  end

  scenario 'login page loads correctly in browser' do
    visit '/login'

    expect(page).to have_css('input[name="username"]')
    expect(page).to have_css('input[name="password"]')
    expect(page).to have_css('input[type="submit"]')
  end

  scenario 'can log in with valid credentials in browser' do
    # Create a test user first
    username = "e2elogin_#{Time.now.to_i}"
    password = 'Password123!'
    hashed_password = BCrypt::Password.create(password)
    DB[:users].insert(
      username: username,
      email: "#{username}@example.com",
      password: hashed_password,
      must_change_password: 0
    )

    visit '/login'

    fill_in 'username', with: username
    fill_in 'password', with: password
    click_button 'Log In'

    # Should redirect to search page after login
    expect(page).to have_current_path('/api/search', ignore_query: true)
  end

  scenario 'shows error for invalid login in browser' do
    visit '/login'

    fill_in 'username', with: 'nonexistent_user'
    fill_in 'password', with: 'wrongpassword'
    click_button 'Log In'

    expect(page).to have_css('.error')
    expect(page).to have_content('Invalid')
  end
end
