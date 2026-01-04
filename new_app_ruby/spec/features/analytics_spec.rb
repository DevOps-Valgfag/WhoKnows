# spec/features/analytics_spec.rb
require_relative '../spec_helper'

RSpec.describe 'Analytics API' do
  describe 'GET /api/recent-searches' do
    it 'returns empty list when no searches have been made' do
      # Clear in-memory searches first
      RECENT_SEARCHES_MUTEX.synchronize { RECENT_SEARCHES.clear }

      get '/api/recent-searches'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)
      expect(json['searches']).to eq([])
      expect(json['max_stored']).to eq(100)
    end

    it 'returns recent searches after performing searches' do
      RECENT_SEARCHES_MUTEX.synchronize { RECENT_SEARCHES.clear }

      # Perform some searches
      get '/?q=ruby'
      get '/?q=python&language=en'

      get '/api/recent-searches'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)

      expect(json['searches'].length).to eq(2)
      expect(json['searches'][0]['query']).to eq('python')
      expect(json['searches'][1]['query']).to eq('ruby')
    end

    it 'respects the limit parameter' do
      RECENT_SEARCHES_MUTEX.synchronize { RECENT_SEARCHES.clear }

      get '/?q=one'
      get '/?q=two'
      get '/?q=three'

      get '/api/recent-searches?limit=2'
      json = JSON.parse(last_response.body)
      expect(json['searches'].length).to eq(2)
    end
  end

  describe 'GET /api/analytics/summary' do
    it 'returns summary of recent searches' do
      RECENT_SEARCHES_MUTEX.synchronize { RECENT_SEARCHES.clear }

      get '/?q=test'
      get '/?q=test'
      get '/?q=ruby'

      get '/api/analytics/summary'
      expect(last_response).to be_ok
      json = JSON.parse(last_response.body)

      expect(json['recent_searches_count']).to eq(3)
      expect(json['top_search_terms']['test']).to eq(2)
      expect(json['top_search_terms']['ruby']).to eq(1)
    end
  end

  describe 'GET /metrics' do
    it 'includes new metrics in output' do
      get '/metrics'
      expect(last_response).to be_ok

      body = last_response.body

      # Check for new metrics presence
      expect(body).to include('whoknows_session_duration_seconds')
      expect(body).to include('whoknows_failed_login_total')
      expect(body).to include('whoknows_page_views_total')
      expect(body).to include('whoknows_active_sessions')
      expect(body).to include('whoknows_search_duration_seconds')
      expect(body).to include('whoknows_weather_api_duration_seconds')
    end
  end
end
