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
end
