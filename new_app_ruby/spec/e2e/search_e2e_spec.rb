require 'spec_helper'

RSpec.feature 'Search E2E', type: :feature, js: true do
  scenario 'homepage loads with search form in browser' do
    visit '/'

    expect(page).to have_css('input[name="q"]')
    expect(page).to have_css('#search-button')
  end

  scenario 'can search for MATLAB and see results in browser' do
    visit '/?q=MATLAB&language=en'

    expect(page).to have_css('.search-result')
    expect(page).to have_css('h3 a')
  end

  scenario 'search form submits correctly' do
    visit '/'

    fill_in 'q', with: 'MATLAB'
    click_button 'search-button'

    expect(page).to have_css('.search-result')
  end
end
