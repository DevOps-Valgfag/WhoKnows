# spec/features/register_spec.rb
require 'spec_helper'

RSpec.feature 'User registration', type: :feature do
  scenario 'user can sign up and is stored in the database' do
    # Unique username so we don't clash with existing users
    username = "testuser_#{Time.now.to_i}"
    email    = "#{username}@example.com"
    password = 'Password123!'

    visit '/register'

    # These match the "name" attributes in views/register.erb
    fill_in 'username', with: username
    fill_in 'email',    with: email
    fill_in 'password', with: password
    fill_in 'password2', with: password
    click_button 'Sign Up'

    # On success, the route redirects to '/'
    expect(page).to have_current_path('/', ignore_query: true)
    expect(page).to have_button('Search')  # sanity check we’re on the search page

    # Now check the database directly
    db = connect_db
    db.results_as_hash = true
    user = db.execute("SELECT * FROM users WHERE username = ?", [username]).first
    db.close

    expect(user).not_to be_nil
    expect(user['email']).to eq(email)
  end
end
