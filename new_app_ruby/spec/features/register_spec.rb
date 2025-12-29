require 'spec_helper'

RSpec.feature 'User registration', type: :feature do
  scenario 'user can sign up and is stored in the database' do
    username = "testuser_#{Time.now.to_i}"
    email    = "#{username}@example.com"
    password = 'Password123!'

    visit '/register'

    fill_in 'username', with: username
    fill_in 'email',    with: email
    fill_in 'password', with: password
    fill_in 'password2', with: password
    click_button 'Sign Up'

    # Redirects to homepage
    expect(page).to have_current_path('/', ignore_query: true)

    # The search button is an icon-only submit button → match ID
    expect(page).to have_css('#search-button')

    # Validate DB record using Sequel's DB constant
    user = DB[:users].where(username: username).first

    expect(user).not_to be_nil
    expect(user[:email]).to eq(email)
  end
end
