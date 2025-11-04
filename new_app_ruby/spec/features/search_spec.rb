require 'spec_helper'

RSpec.feature "Search", type: :feature do
  scenario "user can visit the search page" do
    visit '/'
    expect(page).to have_content 'Search'
  end

  scenario "user can search for 'matlab'" do
    visit '/'
    fill_in 'q', with: 'matlab'
    click_button 'Search'
    expect(page).to have_content 'MATLAB'
  end

  scenario "user can click on login and get to the login page" do
    visit '/'
    click_link 'Log in'
    expect(page).to have_current_path('/login')
  end

  scenario "user can click on register and get to the register page" do
    visit '/'
    click_link 'Register'
    expect(page).to have_current_path('/register')
  end

  scenario "user can click on about and get to the about page" do
    visit '/'
    click_link 'About'
    expect(page).to have_current_path('/about')
  end
end
