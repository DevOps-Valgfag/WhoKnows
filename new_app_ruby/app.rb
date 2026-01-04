require 'sinatra'
require 'sinatra/json'
require 'yaml'
require 'json'
require 'bcrypt'
require 'sinatra/flash'
require 'dotenv/load'
require 'httparty'
require 'time'
require 'timeout'

require 'sequel'
require 'pg'

require 'prometheus/client'
require 'prometheus/client/formats/text'

# ----------------------------
# DB (Postgres via DATABASE_URL)
# ----------------------------
DB = Sequel.connect(
  ENV.fetch('DATABASE_URL'),
  max_connections: Integer(ENV.fetch('DB_POOL', '10')),
  test: true
)

# ----------------------------
# Prometheus metrics
# ----------------------------
PROM_REGISTRY = Prometheus::Client.registry

# Existing metrics
SEARCH_COUNTER = Prometheus::Client::Counter.new(
  :whoknows_search_total,
  docstring: 'Total number of searches',
  labels: [:language]
)
SEARCH_MATCH_COUNTER = Prometheus::Client::Counter.new(
  :whoknows_search_with_match_total,
  docstring: 'Number of searches with at least one match',
  labels: [:language]
)
USER_REGISTERED = Prometheus::Client::Counter.new(
  :whoknows_registered_users_total,
  docstring: 'Total number of registered users'
)
USER_LOGGED_IN = Prometheus::Client::Counter.new(
  :whoknows_login_total,
  docstring: 'Total number of successful logins'
)

# NEW: Session duration histogram (seconds)
SESSION_DURATION = Prometheus::Client::Histogram.new(
  :whoknows_session_duration_seconds,
  docstring: 'Duration of user sessions in seconds',
  buckets: [60, 300, 600, 1800, 3600, 7200, 14_400, 28_800] # 1min to 8hrs
)

# NEW: Failed login attempts counter
FAILED_LOGIN_COUNTER = Prometheus::Client::Counter.new(
  :whoknows_failed_login_total,
  docstring: 'Total number of failed login attempts',
  labels: [:reason]
)

# NEW: Page views counter with logged-in status
PAGE_VIEW_COUNTER = Prometheus::Client::Counter.new(
  :whoknows_page_views_total,
  docstring: 'Total page views',
  labels: %i[path logged_in]
)

# NEW: Active sessions gauge
ACTIVE_SESSIONS = Prometheus::Client::Gauge.new(
  :whoknows_active_sessions,
  docstring: 'Current number of active user sessions'
)

# NEW: Search latency histogram
SEARCH_LATENCY = Prometheus::Client::Histogram.new(
  :whoknows_search_duration_seconds,
  docstring: 'Search request duration in seconds',
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5]
)

# NEW: Weather API latency histogram
WEATHER_API_LATENCY = Prometheus::Client::Histogram.new(
  :whoknows_weather_api_duration_seconds,
  docstring: 'Weather API request duration in seconds',
  buckets: [0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
)

PROM_REGISTRY.register(SEARCH_COUNTER)
PROM_REGISTRY.register(SEARCH_MATCH_COUNTER)
PROM_REGISTRY.register(USER_REGISTERED)
PROM_REGISTRY.register(USER_LOGGED_IN)
PROM_REGISTRY.register(SESSION_DURATION)
PROM_REGISTRY.register(FAILED_LOGIN_COUNTER)
PROM_REGISTRY.register(PAGE_VIEW_COUNTER)
PROM_REGISTRY.register(ACTIVE_SESSIONS)
PROM_REGISTRY.register(SEARCH_LATENCY)
PROM_REGISTRY.register(WEATHER_API_LATENCY)

# ----------------------------
# In-memory storage for recent searches (no DB needed)
# ----------------------------
RECENT_SEARCHES_MUTEX = Mutex.new
RECENT_SEARCHES = []
MAX_RECENT_SEARCHES = 100

def log_search(query, language, results_count, user_id = nil)
  RECENT_SEARCHES_MUTEX.synchronize do
    RECENT_SEARCHES.unshift({
                              query: query,
                              language: language,
                              results_count: results_count,
                              user_id: user_id,
                              timestamp: Time.now.iso8601
                            })
    RECENT_SEARCHES.pop while RECENT_SEARCHES.size > MAX_RECENT_SEARCHES
  end
end

# In-memory session tracking for duration calculation
SESSION_TRACKER_MUTEX = Mutex.new
SESSION_LOGIN_TIMES = {} # session_id => login_time

configure do
  set :trust_proxy, true
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET')
  register Sinatra::Flash
end

set :port, 8080
set :bind, '0.0.0.0'

# ----------------------------
# Load OpenAPI spec
# ----------------------------
SPEC_FILE = File.expand_path('open_api.yaml', __dir__)
OPENAPI_SPEC = YAML.load_file(SPEC_FILE)

get '/open_api.yaml' do
  content_type 'application/yaml'
  File.read(SPEC_FILE)
end

get '/open_api.json' do
  content_type :json
  JSON.pretty_generate(OPENAPI_SPEC)
end

get '/docs' do
  <<-HTML
  <!DOCTYPE html>
  <html>
  <head>
    <title>API Docs</title>
    <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist/swagger-ui.css" />
  </head>
  <body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist/swagger-ui-bundle.js"></script>
    <script>
      window.onload = () => {
        SwaggerUIBundle({
          url: '/open_api.yaml',
          dom_id: '#swagger-ui'
        });
      };
    </script>
  </body>
  </html>
  HTML
end

helpers do
  def truncate_text(text, max_words)
    return '[no content]' if text.nil? || text.strip.empty?

    words = text.split
    return text if words.length <= max_words

    words[0...max_words].join(' ') + '...'
  end

  def perform_search(db, q, language)
    return [] unless q

    stop_words = %w[what are the for is a an in on of to and or with by how]
    keywords = q.downcase.scan(/\w+/).reject { |w| stop_words.include?(w) }

    if keywords.empty?
      return db.fetch(
        'SELECT * FROM pages WHERE language = ? AND (title ILIKE ? OR content ILIKE ?)',
        language, "%#{q}%", "%#{q}%"
      ).all
    end

    conditions = keywords.map { '(title ILIKE ? OR content ILIKE ?)' }.join(' OR ')
    sql = "SELECT * FROM pages WHERE language = ? AND (#{conditions})"

    params = [language]
    keywords.each do |k|
      params << "%#{k}%"
      params << "%#{k}%"
    end

    results = db.fetch(sql, *params).all

    query_down = q.downcase
    results.sort_by! do |row|
      score = 0
      title_down = row[:title].to_s.downcase
      content_down = row[:content].to_s.downcase

      score += 100 if title_down.include?(query_down)
      score += 50 if content_down.include?(query_down)

      keywords.each do |word|
        score += 10 if title_down.include?(word)
        score += 1 if content_down.include?(word)
      end

      -score
    end

    results
  end
end

# ----------------------------
# Request lifecycle
# ----------------------------
before do
  env['g'] ||= {}
  env['g']['db'] = DB

  if session[:user_id]
    user = DB.fetch('SELECT * FROM users WHERE id = ?', session[:user_id]).first
    env['g']['user'] = user
  else
    env['g']['user'] = nil
  end

  # Track page views (skip metrics/assets)
  path = request.path_info
  unless path.start_with?('/metrics', '/assets', '/favicon')
    is_logged_in = !env['g']['user'].nil?
    # Normalize path for metrics (avoid high cardinality)
    normalized_path = normalize_path_for_metrics(path)
    PAGE_VIEW_COUNTER.increment(labels: { path: normalized_path, logged_in: is_logged_in.to_s })
  end
end

# Helper to normalize paths for metrics (avoid cardinality explosion)
def normalize_path_for_metrics(path)
  case path
  when '/' then 'home'
  when %r{^/api/search} then 'search'
  when %r{^/api/weather} then 'weather_api'
  when '/weather' then 'weather'
  when '/login' then 'login'
  when '/register' then 'register'
  when '/about' then 'about'
  when '/docs' then 'docs'
  when '/change_password' then 'change_password'
  else 'other'
  end
end

# ----------------------------
# Root + Search
# ----------------------------
get '/' do
  q = params['q']
  language = params['language'] || 'en'

  if q
    start_time = Time.now
    @search_results = perform_search(DB, q, language)
    SEARCH_LATENCY.observe(Time.now - start_time)

    SEARCH_COUNTER.increment(labels: { language: language })
    SEARCH_MATCH_COUNTER.increment(labels: { language: language }) if @search_results.any?

    # Log search for recent searches list
    user_id = env['g']['user'] ? env['g']['user'][:id] : nil
    log_search(q, language, @search_results.count, user_id)
  else
    @search_results = []
  end

  erb :search
end

get '/api/search' do
  q = params['q']
  language = params['language'] || 'en'

  if q
    start_time = Time.now
    @search_results = perform_search(DB, q, language)
    SEARCH_LATENCY.observe(Time.now - start_time)

    SEARCH_COUNTER.increment(labels: { language: language })
    SEARCH_MATCH_COUNTER.increment(labels: { language: language }) if @search_results.any?

    # Log search for recent searches list
    user_id = env['g']['user'] ? env['g']['user'][:id] : nil
    log_search(q, language, @search_results.count, user_id)
  else
    @search_results = []
  end

  erb :search
end

# ----------------------------
# Auth
# ----------------------------
post '/api/login' do
  username = params['username']
  password = params['password']

  user = DB.fetch('SELECT * FROM users WHERE username = ?', username).first

  error = nil
  if user.nil?
    error = 'Invalid username'
    FAILED_LOGIN_COUNTER.increment(labels: { reason: 'invalid_username' })
  elsif !verify_password(user[:password], password)
    error = 'Invalid password'
    FAILED_LOGIN_COUNTER.increment(labels: { reason: 'invalid_password' })
  else
    session[:user_id] = user[:id]
    USER_LOGGED_IN.increment

    # Track session start time for duration calculation
    SESSION_TRACKER_MUTEX.synchronize do
      SESSION_LOGIN_TIMES[session.id] = Time.now
    end
    ACTIVE_SESSIONS.increment

    if user[:must_change_password].to_i == 1
      redirect '/change_password'
    else
      redirect 'api/search?q='
    end
  end

  if error
    @error = error
    erb :login
  end
end

post '/change_password' do
  unless env['g']['user']
    flash[:error] = 'Session expired. Please log in again.'
    redirect '/login'
  end

  new_pw  = params['new_password']
  new_pw2 = params['new_password2']

  if new_pw.to_s.empty? || new_pw != new_pw2
    flash[:error] = 'Passwords must match and not be empty'
    redirect '/change_password'
  else
    begin
      hashed = BCrypt::Password.create(new_pw)
      DB.fetch(
        'UPDATE users SET password = ?, must_change_password = 0 WHERE id = ?',
        hashed, env['g']['user'][:id]
      ).all

      flash[:success] = 'Password updated successfully!'
      redirect '/api/search?q='
    rescue StandardError => e
      warn "[change_password] ERROR: #{e.class} - #{e.message}"
      flash[:error] = "An unexpected error occurred: #{e.message}"
      redirect '/change_password'
    end
  end
end

post '/api/register' do
  request.body.rewind
  raw_body = request.body.read

  content_type_hdr = request.media_type || request.content_type
  is_json_ct = content_type_hdr && content_type_hdr.downcase.include?('application/json')

  first_char = raw_body.lstrip[0]
  looks_like_json = !raw_body.to_s.strip.empty? && ['{', '['].include?(first_char)

  if (is_json_ct || looks_like_json) && !raw_body.to_s.strip.empty?
    begin
      data = JSON.parse(raw_body)
      params.merge!(data)
      warn "[REGISTER] Parsed JSON body: #{data.inspect}"
    rescue JSON::ParserError
      halt 400, 'Invalid JSON payload'
    end
  end

  username  = params['username']
  email     = params['email']
  password  = params['password']
  password2 = params['password2']

  safe_params = params.reject { |k, _| k.to_s.downcase.include?('password') }
  warn "[REGISTER] Incoming params: #{safe_params.inspect}"

  error = nil
  if username.to_s.empty?
    error = 'You have to enter a username'
  elsif email.to_s.empty? || !email.include?('@')
    error = 'You have to enter a valid email address'
  elsif password.to_s.empty?
    error = 'You have to enter a password'
  elsif password != password2
    error = 'The two passwords do not match'
  else
    user_exists  = DB.fetch('SELECT 1 FROM users WHERE username = ? LIMIT 1', username).first
    email_exists = DB.fetch('SELECT 1 FROM users WHERE email = ? LIMIT 1', email).first

    if user_exists
      error = 'The username is already taken'
    elsif email_exists
      error = 'The email is already registered'
    end
  end

  if error
    if is_json_ct
      status 409
      content_type :json
      return json(success: false, error: error)
    else
      flash[:error] = error
      redirect '/register'
    end
  else
    begin
      hashed_password = BCrypt::Password.create(password)

      new_user_id = DB[:users].insert(
        username: username,
        email: email,
        password: hashed_password,
        must_change_password: 0
      )

      USER_REGISTERED.increment
      session[:user_id] = new_user_id

      warn "[REGISTER] Created user #{username} (ID=#{new_user_id})"
      redirect '/'
    rescue StandardError => e
      warn "[REGISTER] ERROR: #{e.class} - #{e.message}"
      flash[:error] = "Could not register user: #{e.message}"
      redirect '/register'
    end
  end
end

get '/api/logout' do
  # Calculate session duration before clearing
  SESSION_TRACKER_MUTEX.synchronize do
    login_time = SESSION_LOGIN_TIMES.delete(session.id)
    if login_time
      duration = Time.now - login_time
      SESSION_DURATION.observe(duration)
      ACTIVE_SESSIONS.decrement
    end
  end

  session.clear
  flash[:info] = 'Thank you for now. Log in again to continue searching and get the most out of the application.'
  redirect '/login'
end

# ----------------------------
# Pages
# ----------------------------
get '/about' do
  erb :about
end

get '/login' do
  erb :login
end

get '/change_password' do
  redirect '/login' unless env['g']['user']
  erb :change_password
end

get '/register' do
  erb :register
end

get '/debug/headers' do
  content_type 'text/html'
  env.select { |k, _| k.start_with?('HTTP_') }
     .map { |k, v| "#{k}: #{v}" }
     .join('<br>')
end

# ----------------------------
# /metrics
# ----------------------------
get '/metrics' do
  content_type 'text/plain'
  Prometheus::Client::Formats::Text.marshal(PROM_REGISTRY)
end

# ----------------------------
# Weather cache endpoints (uændret)
# ----------------------------
CACHE = { weather: {}, expires_at: {}, stale_until: {} }

def get_weather_data(city, ttl: 300, stale_until: 36_000)
  now = Time.now
  city_key = city.downcase

  if CACHE[:weather][city_key] && CACHE[:expires_at][city_key] > now
    warn "[CACHE HIT] Bruger cached data for #{city}"
    return { data: CACHE[:weather][city_key], status: :fresh }
  end

  warn "[CACHE MISS] Henter nyt data for #{city} fra API"
  url = "https://wttr.in/#{URI.encode_www_form_component(city)}?format=j1"

  begin
    response = HTTParty.get(url, timeout: 5)
    if response.code == 200
      data = JSON.parse(response.body)

      CACHE[:weather][city_key] = data
      CACHE[:expires_at][city_key] = now + ttl
      CACHE[:stale_until][city_key] = now + stale_until

      { data: data, status: :fresh }
    else
      if CACHE[:weather][city_key] && CACHE[:stale_until][city_key] > now
        return { data: CACHE[:weather][city_key], status: :stale }
      end

      nil
    end
  rescue StandardError => e
    warn "[weather] error for #{city}: #{e.class} #{e.message}"
    if CACHE[:weather][city_key] && CACHE[:stale_until][city_key] > now
      return { data: CACHE[:weather][city_key], status: :stale }
    end

    nil
  end
end

# Maximum time (in seconds) before we must respond - set based on your SLA requirement
API_RESPONSE_TIMEOUT = ENV.fetch('API_RESPONSE_TIMEOUT', 5).to_f

get '/api/weather' do
  city = params['city'] || 'Copenhagen'
  result_queue = Queue.new
  start_time = Time.now

  # Start fetching weather data in a background thread
  fetch_thread = Thread.new do
    data = get_weather_data(city)
    result_queue << { success: true, data: data }
  rescue StandardError => e
    result_queue << { success: false, error: e }
  end

  # Wait for result with soft timeout
  begin
    result = Timeout.timeout(API_RESPONSE_TIMEOUT) { result_queue.pop }
    WEATHER_API_LATENCY.observe(Time.now - start_time)

    if result[:success] && result[:data]
      content_type :json
      json(city: city, data: result[:data][:data], status: result[:data][:status])
    else
      status 502
      json(error: "Couldn't fetch weather data for: #{city}")
    end
  rescue Timeout::Error
    WEATHER_API_LATENCY.observe(Time.now - start_time)
    # Soft timeout exceeded - respond gracefully before SLA deadline
    warn "[weather] soft timeout for #{city} - responding with try-again message"
    fetch_thread.kill # Clean up the background thread

    content_type :json
    json(
      success: true,
      city: city,
      message: 'Weather data is temporarily unavailable. Please try again later.',
      retry_after: 30
    )
  end
end

# Maximum time (in seconds) before HTML weather page must respond
HTML_RESPONSE_TIMEOUT = ENV.fetch('HTML_RESPONSE_TIMEOUT', 5).to_f

get '/weather' do
  @city = params['city'] || 'Copenhagen'
  result_queue = Queue.new

  # Start fetching weather data in a background thread
  fetch_thread = Thread.new do
    data = get_weather_data(@city)
    result_queue << { success: true, data: data }
  rescue StandardError => e
    result_queue << { success: false, error: e }
  end

  # Wait for result with soft timeout
  begin
    result = Timeout.timeout(HTML_RESPONSE_TIMEOUT) { result_queue.pop }

    if result[:success] && result[:data]
      @current_condition = result[:data][:data]['current_condition'][0]
      @forecast = result[:data][:data]['weather']
      @status = result[:data][:status]
      erb :weather
    else
      @error = "Could not fetch weather data for #{@city}"
      erb :weather
    end
  rescue Timeout::Error
    # Soft timeout exceeded - respond gracefully
    warn "[weather] soft timeout for #{@city} - responding with try-again message"
    fetch_thread.kill

    @error = 'Weather data is temporarily unavailable. Please try again later.'
    @retry_message = true
    erb :weather
  end
end

# ----------------------------
# Security functions
# ----------------------------
def hash_password(password)
  BCrypt::Password.create(password)
end

def verify_password(stored_hash, password)
  BCrypt::Password.new(stored_hash) == password
rescue BCrypt::Errors::InvalidHash
  false
end

# ----------------------------
# Analytics API endpoints
# ----------------------------

# GET /api/recent-searches - Returns the last N search queries
get '/api/recent-searches' do
  limit = [params['limit']&.to_i || 50, MAX_RECENT_SEARCHES].min
  limit = 10 if limit <= 0

  searches = RECENT_SEARCHES_MUTEX.synchronize { RECENT_SEARCHES.first(limit) }

  content_type :json
  json(
    searches: searches,
    total_in_memory: RECENT_SEARCHES.size,
    max_stored: MAX_RECENT_SEARCHES
  )
end

# GET /api/analytics/summary - Quick summary of key metrics
get '/api/analytics/summary' do
  searches = RECENT_SEARCHES_MUTEX.synchronize { RECENT_SEARCHES.dup }

  # Calculate top search terms (last 100 searches)
  term_counts = searches.each_with_object(Hash.new(0)) { |s, h| h[s[:query].downcase] += 1 }
  top_terms = term_counts.sort_by { |_, v| -v }.first(10).to_h

  content_type :json
  json(
    recent_searches_count: searches.size,
    top_search_terms: top_terms,
    searches_with_results: searches.count { |s| s[:results_count] > 0 },
    searches_without_results: searches.count { |s| s[:results_count] == 0 }
  )
end
