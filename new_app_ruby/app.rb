require "sinatra"
require "sinatra/json"
require "yaml"
require "json"
require "bcrypt"
require "sinatra/flash"
require "dotenv/load"
require "httparty"
require "time"

require "sequel"
require "pg"

require "prometheus/client"
require "prometheus/client/formats/text"

# ----------------------------
# DB (Postgres via DATABASE_URL)
# ----------------------------
DB = Sequel.connect(
  ENV.fetch("DATABASE_URL"),
  max_connections: Integer(ENV.fetch("DB_POOL", "10")),
  test: true
)

# ----------------------------
# Prometheus metrics
# ----------------------------
# Philosophy: "Monitoring is for asking questions"
# Each metric is designed to answer specific operational questions
PROM_REGISTRY = Prometheus::Client.registry

# ===========================================
# BUSINESS METRICS - Understanding user behavior
# ===========================================

# Q: How many searches are being performed? Which languages are popular?
SEARCH_COUNTER = Prometheus::Client::Counter.new(
  :whoknows_search_total,
  docstring: "Total number of searches",
  labels: [:language]
)

# Q: Are users finding what they're looking for?
SEARCH_MATCH_COUNTER = Prometheus::Client::Counter.new(
  :whoknows_search_with_match_total,
  docstring: "Number of searches with at least one match",
  labels: [:language]
)

# Q: How many results do searches typically return? (distribution)
SEARCH_RESULTS_HISTOGRAM = Prometheus::Client::Histogram.new(
  :whoknows_search_results_count,
  docstring: "Distribution of search result counts",
  labels: [:language],
  buckets: [0, 1, 5, 10, 25, 50, 100, 250]
)

# Q: How many users have registered over time?
USER_REGISTERED = Prometheus::Client::Counter.new(
  :whoknows_registered_users_total,
  docstring: "Total number of registered users"
)

# Q: How active are users logging in?
USER_LOGGED_IN = Prometheus::Client::Counter.new(
  :whoknows_login_total,
  docstring: "Total number of successful logins"
)

# Q: How many users change their password?
PASSWORD_CHANGED = Prometheus::Client::Counter.new(
  :whoknows_password_changed_total,
  docstring: "Total number of successful password changes"
)

# ===========================================
# PERFORMANCE METRICS - Understanding latency
# ===========================================

# Q: How long do HTTP requests take? Which endpoints are slow?
HTTP_REQUEST_DURATION = Prometheus::Client::Histogram.new(
  :whoknows_http_request_duration_seconds,
  docstring: "HTTP request duration in seconds",
  labels: [:method, :path, :status],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
)

# Q: How long do searches take? Is search performance degrading?
SEARCH_DURATION = Prometheus::Client::Histogram.new(
  :whoknows_search_duration_seconds,
  docstring: "Search query execution time in seconds",
  labels: [:language],
  buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1]
)

# Q: How long do database queries take?
DB_QUERY_DURATION = Prometheus::Client::Histogram.new(
  :whoknows_db_query_duration_seconds,
  docstring: "Database query execution time in seconds",
  labels: [:operation],
  buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1]
)

# ===========================================
# ERROR METRICS - Understanding failures
# ===========================================

# Q: How many login attempts are failing? Why?
LOGIN_FAILED = Prometheus::Client::Counter.new(
  :whoknows_login_failed_total,
  docstring: "Total number of failed login attempts",
  labels: [:reason]
)

# Q: How many registrations are failing? Why?
REGISTRATION_FAILED = Prometheus::Client::Counter.new(
  :whoknows_registration_failed_total,
  docstring: "Total number of failed registration attempts",
  labels: [:reason]
)

# Q: What HTTP errors are occurring?
HTTP_ERRORS = Prometheus::Client::Counter.new(
  :whoknows_http_errors_total,
  docstring: "Total number of HTTP errors",
  labels: [:status, :path]
)

# ===========================================
# EXTERNAL SERVICE METRICS - Weather API
# ===========================================

# Q: Is the weather API reliable? How often does it fail?
WEATHER_API_REQUESTS = Prometheus::Client::Counter.new(
  :whoknows_weather_api_requests_total,
  docstring: "Total weather API requests",
  labels: [:status]
)

# Q: How long does the weather API take to respond?
WEATHER_API_DURATION = Prometheus::Client::Histogram.new(
  :whoknows_weather_api_duration_seconds,
  docstring: "Weather API response time in seconds",
  buckets: [0.1, 0.25, 0.5, 1, 2.5, 5, 10]
)

# Q: Is the cache effective? Are we reducing API calls?
WEATHER_CACHE_STATUS = Prometheus::Client::Counter.new(
  :whoknows_weather_cache_total,
  docstring: "Weather cache hits/misses",
  labels: [:status]
)

# ===========================================
# SYSTEM STATE GAUGES - Current state snapshot
# ===========================================

# Q: How many pages are indexed? Is content growing?
PAGES_TOTAL = Prometheus::Client::Gauge.new(
  :whoknows_pages_total,
  docstring: "Total number of indexed pages",
  labels: [:language]
)

# Q: How many users exist in the system?
USERS_TOTAL = Prometheus::Client::Gauge.new(
  :whoknows_users_total,
  docstring: "Total number of registered users in database"
)

# Register all metrics
[
  SEARCH_COUNTER, SEARCH_MATCH_COUNTER, SEARCH_RESULTS_HISTOGRAM,
  USER_REGISTERED, USER_LOGGED_IN, PASSWORD_CHANGED,
  HTTP_REQUEST_DURATION, SEARCH_DURATION, DB_QUERY_DURATION,
  LOGIN_FAILED, REGISTRATION_FAILED, HTTP_ERRORS,
  WEATHER_API_REQUESTS, WEATHER_API_DURATION, WEATHER_CACHE_STATUS,
  PAGES_TOTAL, USERS_TOTAL
].each { |metric| PROM_REGISTRY.register(metric) }

configure do
  set :trust_proxy, true
  enable :sessions
  set :session_secret, ENV.fetch("SESSION_SECRET")
  register Sinatra::Flash
end

set :port, 8080
set :bind, "0.0.0.0"

# ----------------------------
# Load OpenAPI spec
# ----------------------------
SPEC_FILE = File.expand_path("open_api.yaml", __dir__)
OPENAPI_SPEC = YAML.load_file(SPEC_FILE)

get "/open_api.yaml" do
  content_type "application/yaml"
  File.read(SPEC_FILE)
end

get "/open_api.json" do
  content_type :json
  JSON.pretty_generate(OPENAPI_SPEC)
end

get "/docs" do
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
    return "[no content]" if text.nil? || text.strip.empty?

    words = text.split
    return text if words.length <= max_words
    words[0...max_words].join(" ") + "..."
  end

  def perform_search(db, q, language)
    return [] unless q

    stop_words = %w[what are the for is a an in on of to and or with by how]
    keywords = q.downcase.scan(/\w+/).reject { |w| stop_words.include?(w) }

    if keywords.empty?
      return db.fetch(
        "SELECT * FROM pages WHERE language = ? AND (title ILIKE ? OR content ILIKE ?)",
        language, "%#{q}%", "%#{q}%"
      ).all
    end

    conditions = keywords.map { "(title ILIKE ? OR content ILIKE ?)" }.join(" OR ")
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
  env["g"] ||= {}
  env["g"]["db"] = DB
  env["g"]["request_start"] = Time.now

  if session[:user_id]
    start = Time.now
    user = DB.fetch("SELECT * FROM users WHERE id = ?", session[:user_id]).first
    DB_QUERY_DURATION.observe(Time.now - start, labels: { operation: "user_lookup" })
    env["g"]["user"] = user
  else
    env["g"]["user"] = nil
  end
end

after do
  # Track HTTP request duration
  # Q: How long did this request take?
  if env["g"]["request_start"]
    duration = Time.now - env["g"]["request_start"]
    path = normalize_path(request.path)
    HTTP_REQUEST_DURATION.observe(duration, labels: {
      method: request.request_method,
      path: path,
      status: response.status.to_s
    })

    # Track HTTP errors separately for alerting
    # Q: Are we experiencing elevated error rates?
    if response.status >= 400
      HTTP_ERRORS.increment(labels: { status: response.status.to_s, path: path })
    end
  end
end

# Normalize paths to avoid high cardinality (e.g., /api/search?q=foo -> /api/search)
def normalize_path(path)
  case path
  when "/" then "/"
  when /^\/api\/search/ then "/api/search"
  when /^\/api\/weather/ then "/api/weather"
  when /^\/api\/login/ then "/api/login"
  when /^\/api\/register/ then "/api/register"
  when /^\/api\/logout/ then "/api/logout"
  when /^\/weather/ then "/weather"
  when /^\/metrics/ then "/metrics"
  when /^\/docs/ then "/docs"
  when /^\/login/ then "/login"
  when /^\/register/ then "/register"
  when /^\/about/ then "/about"
  when /^\/change_password/ then "/change_password"
  else "/other"
  end
end

# ----------------------------
# Root + Search
# ----------------------------

# Helper to track search metrics
def track_search_metrics(results, language, duration)
  SEARCH_COUNTER.increment(labels: { language: language })
  SEARCH_MATCH_COUNTER.increment(labels: { language: language }) if results.any?
  # Q: How many results do searches return? (helps tune relevance)
  SEARCH_RESULTS_HISTOGRAM.observe(results.length, labels: { language: language })
  # Q: How long do searches take? (performance monitoring)
  SEARCH_DURATION.observe(duration, labels: { language: language })
end

get "/" do
  q = params["q"]
  language = params["language"] || "en"

  if q
    search_start = Time.now
    @search_results = perform_search(DB, q, language)
    track_search_metrics(@search_results, language, Time.now - search_start)
  else
    @search_results = []
  end

  erb :search
end

get "/api/search" do
  q = params["q"]
  language = params["language"] || "en"

  if q
    search_start = Time.now
    @search_results = perform_search(DB, q, language)
    track_search_metrics(@search_results, language, Time.now - search_start)
  else
    @search_results = []
  end

  erb :search
end

# ----------------------------
# Auth
# ----------------------------
post "/api/login" do
  username = params["username"]
  password = params["password"]

  db_start = Time.now
  user = DB.fetch("SELECT * FROM users WHERE username = ?", username).first
  DB_QUERY_DURATION.observe(Time.now - db_start, labels: { operation: "login_lookup" })

  error = nil
  if user.nil?
    error = "Invalid username"
    # Q: How many logins fail? Why? (security monitoring, UX issues)
    LOGIN_FAILED.increment(labels: { reason: "invalid_username" })
  elsif !verify_password(user[:password], password)
    error = "Invalid password"
    # Q: Are there brute force attempts? (could indicate attack)
    LOGIN_FAILED.increment(labels: { reason: "invalid_password" })
  else
    session[:user_id] = user[:id]
    USER_LOGGED_IN.increment

    if user[:must_change_password].to_i == 1
      redirect "/change_password"
    else
      redirect "api/search?q="
    end
  end

  if error
    @error = error
    erb :login
  end
end

post "/change_password" do
  unless env["g"]["user"]
    flash[:error] = "Session expired. Please log in again."
    redirect "/login"
  end

  new_pw  = params["new_password"]
  new_pw2 = params["new_password2"]

  if new_pw.to_s.empty? || new_pw != new_pw2
    flash[:error] = "Passwords must match and not be empty"
    redirect "/change_password"
  else
    begin
      hashed = BCrypt::Password.create(new_pw)
      db_start = Time.now
      DB.fetch(
        "UPDATE users SET password = ?, must_change_password = 0 WHERE id = ?",
        hashed, env["g"]["user"][:id]
      ).all
      DB_QUERY_DURATION.observe(Time.now - db_start, labels: { operation: "password_update" })

      # Q: How often do users change passwords? (security hygiene)
      PASSWORD_CHANGED.increment
      flash[:success] = "Password updated successfully!"
      redirect "/api/search?q="
    rescue => e
      warn "[change_password] ERROR: #{e.class} - #{e.message}"
      flash[:error] = "An unexpected error occurred: #{e.message}"
      redirect "/change_password"
    end
  end
end

post "/api/register" do
  request.body.rewind
  raw_body = request.body.read

  content_type_hdr = request.media_type || request.content_type
  is_json_ct = content_type_hdr && content_type_hdr.downcase.include?("application/json")

  first_char = raw_body.lstrip[0]
  looks_like_json = !raw_body.to_s.strip.empty? && ["{", "["].include?(first_char)

  if (is_json_ct || looks_like_json) && !raw_body.to_s.strip.empty?
    begin
      data = JSON.parse(raw_body)
      params.merge!(data)
      warn "[REGISTER] Parsed JSON body: #{data.inspect}"
    rescue JSON::ParserError
      halt 400, "Invalid JSON payload"
    end
  end

  username  = params["username"]
  email     = params["email"]
  password  = params["password"]
  password2 = params["password2"]

  warn "[REGISTER] Incoming params: #{params.inspect}"

  error = nil
  failure_reason = nil

  if username.to_s.empty?
    error = "You have to enter a username"
    failure_reason = "missing_username"
  elsif email.to_s.empty? || !email.include?("@")
    error = "You have to enter a valid email address"
    failure_reason = "invalid_email"
  elsif password.to_s.empty?
    error = "You have to enter a password"
    failure_reason = "missing_password"
  elsif password != password2
    error = "The two passwords do not match"
    failure_reason = "password_mismatch"
  else
    db_start = Time.now
    user_exists  = DB.fetch("SELECT 1 FROM users WHERE username = ? LIMIT 1", username).first
    email_exists = DB.fetch("SELECT 1 FROM users WHERE email = ? LIMIT 1", email).first
    DB_QUERY_DURATION.observe(Time.now - db_start, labels: { operation: "registration_check" })

    if user_exists
      error = "The username is already taken"
      failure_reason = "username_taken"
    elsif email_exists
      error = "The email is already registered"
      failure_reason = "email_taken"
    end
  end

  if error
    # Q: Why are registrations failing? (UX issues, spam attempts)
    REGISTRATION_FAILED.increment(labels: { reason: failure_reason })
    if is_json_ct
      status 409
      content_type :json
      return json(success: false, error: error)
    else
      flash[:error] = error
      redirect "/register"
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
      redirect "/"
    rescue => e
      warn "[REGISTER] ERROR: #{e.class} - #{e.message}"
      flash[:error] = "Could not register user: #{e.message}"
      redirect "/register"
    end
  end
end

get "/api/logout" do
  session.clear
  flash[:info] = "Thank you for now. Log in again to continue searching and get the most out of the application."
  redirect "/login"
end

# ----------------------------
# Pages
# ----------------------------
get "/about" do
  erb :about
end

get "/login" do
  erb :login
end

get "/change_password" do
  redirect "/login" unless env["g"]["user"]
  erb :change_password
end

get "/register" do
  erb :register
end

get "/debug/headers" do
  content_type "text/html"
  env.select { |k, _| k.start_with?("HTTP_") }
     .map { |k, v| "#{k}: #{v}" }
     .join("<br>")
end

# ----------------------------
# /metrics
# ----------------------------

# Helper to update gauge metrics on each scrape
def update_gauge_metrics
  # Q: How many pages are indexed? Is content growing?
  begin
    page_counts = DB.fetch("SELECT language, COUNT(*) as count FROM pages GROUP BY language").all
    page_counts.each do |row|
      PAGES_TOTAL.set(row[:count], labels: { language: row[:language] })
    end
  rescue => e
    warn "[metrics] Failed to update page counts: #{e.message}"
  end

  # Q: How many users exist in the system?
  begin
    user_count = DB.fetch("SELECT COUNT(*) as count FROM users").first[:count]
    USERS_TOTAL.set(user_count)
  rescue => e
    warn "[metrics] Failed to update user count: #{e.message}"
  end
end

get "/metrics" do
  # Refresh gauge values before serving metrics
  update_gauge_metrics
  content_type "text/plain"
  Prometheus::Client::Formats::Text.marshal(PROM_REGISTRY)
end

# ----------------------------
# Weather cache endpoints
# ----------------------------
CACHE = { weather: {}, expires_at: {}, stale_until: {} }

def get_weather_data(city, ttl: 300, stale_until: 36000)
  now = Time.now
  city_key = city.downcase

  # Q: Is the cache effective? (reduces API load, improves latency)
  if CACHE[:weather][city_key] && CACHE[:expires_at][city_key] > now
    warn "[CACHE HIT] Bruger cached data for #{city}"
    WEATHER_CACHE_STATUS.increment(labels: { status: "hit" })
    return { data: CACHE[:weather][city_key], status: :fresh }
  end

  warn "[CACHE MISS] Henter nyt data for #{city} fra API"
  WEATHER_CACHE_STATUS.increment(labels: { status: "miss" })

  url = "https://wttr.in/#{URI.encode_www_form_component(city)}?format=j1"

  begin
    api_start = Time.now
    response = HTTParty.get(url, timeout: 5)
    api_duration = Time.now - api_start

    # Q: How long does the weather API take? (external dependency performance)
    WEATHER_API_DURATION.observe(api_duration)

    if response.code == 200
      # Q: Is the weather API reliable?
      WEATHER_API_REQUESTS.increment(labels: { status: "success" })
      data = JSON.parse(response.body)

      CACHE[:weather][city_key] = data
      CACHE[:expires_at][city_key] = now + ttl
      CACHE[:stale_until][city_key] = now + stale_until

      return { data: data, status: :fresh }
    else
      WEATHER_API_REQUESTS.increment(labels: { status: "error_#{response.code}" })
      if CACHE[:weather][city_key] && CACHE[:stale_until][city_key] > now
        WEATHER_CACHE_STATUS.increment(labels: { status: "stale_fallback" })
        return { data: CACHE[:weather][city_key], status: :stale }
      end
      nil
    end
  rescue StandardError => e
    warn "[weather] error for #{city}: #{e.class} #{e.message}"
    # Q: What types of failures occur? (timeout, network, etc.)
    WEATHER_API_REQUESTS.increment(labels: { status: "exception" })
    if CACHE[:weather][city_key] && CACHE[:stale_until][city_key] > now
      WEATHER_CACHE_STATUS.increment(labels: { status: "stale_fallback" })
      return { data: CACHE[:weather][city_key], status: :stale }
    end
    nil
  end
end

get "/api/weather" do
  city = params["city"] || "Copenhagen"
  result = get_weather_data(city)

  if result
    content_type :json
    json(city: city, data: result[:data], status: result[:status])
  else
    status 502
    json(error: "Couldn't fetch weather data for: #{city}")
  end
end

get "/weather" do
  @city = params["city"] || "Copenhagen"
  result = get_weather_data(@city)

  if result
    @current_condition = result[:data]["current_condition"][0]
    @forecast = result[:data]["weather"]
    @status = result[:status]
    erb :weather
  else
    @error = "Kunne ikke hente vejrdata for #{@city}"
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
