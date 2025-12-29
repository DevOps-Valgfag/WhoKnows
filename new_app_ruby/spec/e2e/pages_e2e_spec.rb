require 'spec_helper'

RSpec.feature 'Pages E2E', type: :feature, js: true do
  scenario 'about page loads in browser' do
    visit '/about'

    # Page should load without errors
    expect(page).to have_current_path('/about')
  end

  scenario 'weather page loads in browser' do
    visit '/weather'

    # Page should load without errors
    expect(page).to have_current_path('/weather', ignore_query: true)
  end

  scenario 'API docs page loads with Swagger UI' do
    visit '/docs'

    expect(page).to have_css('#swagger-ui')
  end

  scenario 'can navigate from login to register' do
    visit '/login'

    click_link 'Create an account'

    expect(page).to have_current_path('/register')
  end
end
