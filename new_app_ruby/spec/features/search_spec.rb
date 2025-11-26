require 'spec_helper'

RSpec.feature 'Search', type: :feature do
  scenario 'searching for MATLAB shows a MATLAB result' do
    visit '/?q=MATLAB&language=en'

    # Expect at least one search result container
    expect(page).to have_css('.search-result')

    # Expect the title to appear inside an <h3><a> tag
    expect(page).to have_css('h3 a', text: 'MATLAB')
  end
end
