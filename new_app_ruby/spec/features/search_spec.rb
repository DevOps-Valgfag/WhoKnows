require 'spec_helper'

RSpec.feature 'Search', type: :feature do
  scenario 'searching for MATLAB shows a MATLAB result' do
    visit '/?q=MATLAB&language=en'

    expect(page.status_code).to eq 200

    expect(page).to have_css('.search-result-title', text: 'MATLAB')

    expect(page).to have_content('MATLAB')
  end
end
