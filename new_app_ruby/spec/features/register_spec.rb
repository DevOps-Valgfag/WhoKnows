# spec/features/register_spec.rb
require 'spec_helper'

RSpec.feature 'User registration', type: :feature do
  scenario 'user can sign up and is stored in the database' do
    username = "testuser_#{Time.now.to_i}"
    email    = "#{username}@example.com"
    password = 'Password123!'

    begin
      visit '/register'

      fill_in 'username',  with: username
      fill_in 'email',     with: email
      fill_in 'password',  with: password
      fill_in 'password2', with: password
      click_button 'Sign Up'

      # Should redirect to home page
      expect(page).to have_current_path('/', ignore_query: true)
      expect(page).to have_button('Search')

      # Check DB
      db = connect_db
      db.results_as_hash = true
      user = db.execute("SELECT * FROM users WHERE username = ?", [username]).first

      expect(user).not_to be_nil
      expect(user['email']).to eq(email)

      # MUST match what app.rb actually inserts (0)
      expect(user['must_change_password']).to eq(0)

    ensure
      # cleanup user
      cleanup = connect_db
      cleanup.execute("DELETE FROM users WHERE username = ?", [username])
      cleanup.close
    end
  end
end
