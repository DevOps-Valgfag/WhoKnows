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

# --- NEW METRICS: Answering "What are users searching?" ---
SEARCH_TERMS_COUNTER = Prometheus::Client::Counter.new(
  :whoknows_search_terms_total,
  docstring: 'Search terms used by users',
  labels: [:term]
)

# --- NEW METRICS: Answering "How many users do we have?" ---
TOTAL_USERS_GAUGE = Prometheus::Client::Gauge.new(
  :whoknows_total_users,
  docstring: 'Total number of registered users in database'
)

# --- NEW METRICS: Answering "How long are they logged in?" ---
SESSION_DURATION_HISTOGRAM = Prometheus::Client::Histogram.new(
  :whoknows_session_duration_seconds,
  docstring: 'Duration of user sessions in seconds',
  buckets: [60, 300, 600, 1800, 3600, 7200, 14400, 28800] # 1min, 5min, 10min, 30min, 1h, 2h, 4h, 8h
)

# --- NEW METRICS: Request latency ---
REQUEST_DURATION_HISTOGRAM = Prometheus::Client::Histogram.new(
  :whoknows_request_duration_seconds,
  docstring: 'HTTP request duration in seconds',
  labels: [:method, :path, :status],
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
)

# --- NEW METRICS: Page views ---
PAGE_VIEWS_COUNTER = Prometheus::Client::Counter.new(
  :whoknows_page_views_total,
  docstring: 'Total page views by path',
  labels: [:path]
)

# --- NEW METRICS: Weather API monitoring ---
WEATHER_CACHE_HIT_COUNTER = Prometheus::Client::Counter.new(
  :whoknows_weather_cache_hits_total,
  docstring: 'Weather cache hits'
)
WEATHER_CACHE_MISS_COUNTER = Prometheus::Client::Counter.new(
  :whoknows_weather_cache_misses_total,
  docstring: 'Weather cache misses'
)
WEATHER_API_ERROR_COUNTER = Prometheus::Client::Counter.new(
  :whoknows_weather_api_errors_total,
  docstring: 'Weather API errors'
)

# --- NEW METRICS: Security monitoring ---
LOGIN_FAILED_COUNTER = Prometheus::Client::Counter.new(
  :whoknows_login_failed_total,
  docstring: 'Total number of failed login attempts',
  labels: [:reason]
)

# --- NEW METRICS: Active sessions ---
ACTIVE_SESSIONS_GAUGE = Prometheus::Client::Gauge.new(
  :whoknows_active_sessions,
  docstring: 'Number of active user sessions'
)

PROM_REGISTRY.register(SEARCH_COUNTER)
PROM_REGISTRY.register(SEARCH_MATCH_COUNTER)
PROM_REGISTRY.register(USER_REGISTERED)
PROM_REGISTRY.register(USER_LOGGED_IN)
PROM_REGISTRY.register(SEARCH_TERMS_COUNTER)
PROM_REGISTRY.register(TOTAL_USERS_GAUGE)
PROM_REGISTRY.register(SESSION_DURATION_HISTOGRAM)
PROM_REGISTRY.register(REQUEST_DURATION_HISTOGRAM)
PROM_REGISTRY.register(PAGE_VIEWS_COUNTER)
PROM_REGISTRY.register(WEATHER_CACHE_HIT_COUNTER)
PROM_REGISTRY.register(WEATHER_CACHE_MISS_COUNTER)
PROM_REGISTRY.register(WEATHER_API_ERROR_COUNTER)
PROM_REGISTRY.register(LOGIN_FAILED_COUNTER)
PROM_REGISTRY.register(ACTIVE_SESSIONS_GAUGE)

configure do
  set :trust_proxy, true
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET')
  register Sinatra::Flash
end

# --- Session tracking storage (in-memory for active sessions) ---
ACTIVE_SESSIONS = {}
ACTIVE_SESSIONS_MUTEX = Mutex.new

# Helper to sanitize search terms for metrics (avoid cardinality explosion)
def sanitize_search_term(term)
  return 'empty' if term.nil? || term.strip.empty?

  normalized = term.downcase.strip.gsub(/\s+/, ' ')
  # Truncate long queries and limit to first 50 chars
  normalized = normalized[0, 50]
  # Replace special chars with underscore
  normalized.gsub(/[^a-z0-9\s]/, '_')
end

# Helper to normalize path for metrics (avoid cardinality explosion from query params)
def normalize_path(path)
  case path
  when '/', '/api/search' then '/search'
  when '/weather', '/api/weather' then '/weather'
  when '/login', '/api/login' then '/login'
  when '/register', '/api/register' then '/register'
  when '/api/logout' then '/logout'
  when '/about' then '/about'
  when '/change_password' then '/change_password'
  when '/metrics' then '/metrics'
  when '/docs' then '/docs'
  else '/other'
  end
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
  env['g']['request_start'] = Time.now

  if session[:user_id]
    user = DB.fetch('SELECT * FROM users WHERE id = ?', session[:user_id]).first
    env['g']['user'] = user
  else
    env['g']['user'] = nil
  end
end

after do
  # Skip metrics for the metrics endpoint itself
  next if request.path_info == '/metrics'

  # Track request duration
  if env['g'] && env['g']['request_start']
    duration = Time.now - env['g']['request_start']
    normalized_path = normalize_path(request.path_info)
    REQUEST_DURATION_HISTOGRAM.observe(
      duration,
      labels: { method: request.request_method, path: normalized_path, status: response.status.to_s }
    )

    # Track page views (only for GET requests to main pages)
    if request.request_method == 'GET' && !request.path_info.start_with?('/api/')
      PAGE_VIEWS_COUNTER.increment(labels: { path: normalized_path })
    end
  end
end

# ----------------------------
# Root + Search
# ----------------------------
get '/' do
  q = params['q']
  language = params['language'] || 'en'

  if q
    @search_results = perform_search(DB, q, language)
    SEARCH_COUNTER.increment(labels: { language: language })
    SEARCH_MATCH_COUNTER.increment(labels: { language: language }) if @search_results.any?
    # Track what users are searching for
    sanitized_term = sanitize_search_term(q)
    SEARCH_TERMS_COUNTER.increment(labels: { term: sanitized_term })
  else
    @search_results = []
  end

  erb :search
end

get '/api/search' do
  q = params['q']
  language = params['language'] || 'en'

  if q
    @search_results = perform_search(DB, q, language)
    SEARCH_COUNTER.increment(labels: { language: language })
    SEARCH_MATCH_COUNTER.increment(labels: { language: language }) if @search_results.any?
    # Track what users are searching for
    sanitized_term = sanitize_search_term(q)
    SEARCH_TERMS_COUNTER.increment(labels: { term: sanitized_term })
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
    LOGIN_FAILED_COUNTER.increment(labels: { reason: 'invalid_username' })
  elsif !verify_password(user[:password], password)
    error = 'Invalid password'
    LOGIN_FAILED_COUNTER.increment(labels: { reason: 'invalid_password' })
  else
    session[:user_id] = user[:id]
    session[:login_time] = Time.now.to_i # Track session start for duration calculation
    USER_LOGGED_IN.increment

    # Track active session
    ACTIVE_SESSIONS_MUTEX.synchronize do
      ACTIVE_SESSIONS[user[:id]] = Time.now
      ACTIVE_SESSIONS_GAUGE.set(ACTIVE_SESSIONS.size)
    end

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
  # Track session duration before clearing
  if session[:login_time]
    duration = Time.now.to_i - session[:login_time]
    SESSION_DURATION_HISTOGRAM.observe(duration)
  end

  # Remove from active sessions
  if session[:user_id]
    ACTIVE_SESSIONS_MUTEX.synchronize do
      ACTIVE_SESSIONS.delete(session[:user_id])
      ACTIVE_SESSIONS_GAUGE.set(ACTIVE_SESSIONS.size)
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
  # Refresh gauge metrics before responding
  begin
    user_count = DB.fetch('SELECT COUNT(*) AS count FROM users').first[:count]
    TOTAL_USERS_GAUGE.set(user_count)
  rescue StandardError => e
    warn "[metrics] Error fetching user count: #{e.message}"
  end

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
    WEATHER_CACHE_HIT_COUNTER.increment
    return { data: CACHE[:weather][city_key], status: :fresh }
  end

  warn "[CACHE MISS] Henter nyt data for #{city} fra API"
  WEATHER_CACHE_MISS_COUNTER.increment
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
      WEATHER_API_ERROR_COUNTER.increment
      if CACHE[:weather][city_key] && CACHE[:stale_until][city_key] > now
        return { data: CACHE[:weather][city_key], status: :stale }
      end

      nil
    end
  rescue StandardError => e
    warn "[weather] error for #{city}: #{e.class} #{e.message}"
    WEATHER_API_ERROR_COUNTER.increment
    if CACHE[:weather][city_key] && CACHE[:stale_until][city_key] > now
      return { data: CACHE[:weather][city_key], status: :stale }
    end

    nil
  end
end

# Maximum time (in seconds) before we must respond - set based on your SLA requirement
API_RESPONSE_TIMEOUT = ENV.fetch('API_RESPONSE_TIMEOUT', 9.5).to_f

get '/api/weather' do
  city = params['city'] || 'Copenhagen'
  result_queue = Queue.new

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

    if result[:success] && result[:data]
      content_type :json
      json(city: city, data: result[:data][:data], status: result[:data][:status])
    else
      status 502
      json(error: "Couldn't fetch weather data for: #{city}")
    end
  rescue Timeout::Error
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
HTML_RESPONSE_TIMEOUT = ENV.fetch('HTML_RESPONSE_TIMEOUT', 5.5).to_f

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
