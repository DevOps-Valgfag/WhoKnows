require "sinatra"
require "sinatra/json"
require "yaml"
require "json"
require "sqlite3"
require "bcrypt"
require "sinatra/flash"
require "dotenv/load"
require "httparty" # Gem for making HTTP requests
require "time"

# Mere detaljerede muligheder for debug (både bedre browser og terminal visning)
# set :show_exceptions, true
# set :raise_errors, true

configure do
  set :trust_proxy, true    # Fortæller Sinatra at stole på Nginx’ headers, så vi får korrekt redirect ved deploy
  enable :sessions
  set :session_secret, ENV.fetch("SESSION_SECRET")
  register Sinatra::Flash
end

# ----------------------------
# Server konfiguration
# ----------------------------
set :port, 8080
set :bind, "0.0.0.0"


# ----------------------------
# Database path
# ----------------------------
DB_PATH = File.join(settings.root, 'whoknows.db')

# Helper: åbn DB
def connect_db
  SQLite3::Database.new(DB_PATH)
end

# ----------------------------
# Load OpenAPI spec
# ----------------------------
SPEC_FILE = File.expand_path("open_api.yaml", __dir__)
OPENAPI_SPEC = YAML.load_file(SPEC_FILE)

# Serve YAML
get "/open_api.yaml" do
  content_type "application/yaml"
  File.read(SPEC_FILE)
end

# Serve JSON
get "/open_api.json" do
  content_type :json
  JSON.pretty_generate(OPENAPI_SPEC)
end

# Openapi docs with Swagger UI
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

# Root endpoint
get "/" do
  q = params["q"]
  language = params["language"] || "en"

  db = connect_db
  db.results_as_hash = true

  @search_results = if q
    # This part correctly handles the search query from the form
    db.execute("SELECT * FROM pages WHERE language = ? AND content LIKE ?", [language, "%#{q}%"])
  else
    []
  end

  db.close

  # This renders the search page with the results
  erb :search
end

# ----------------------------
# Request Handlers
# ----------------------------

before do
  # Global variabel to contain data
  env['g'] ||= {}
  env['g']['db'] = connect_db
  env['g']['db'].results_as_hash = true  # med denne returnerer SQLite rækker som hashes i stedet for arrays..

  # Handle user-session
  if session[:user_id]
    user = env['g']['db'].execute("SELECT * FROM users WHERE id = ?", session[:user_id]).first
    env['g']['user'] = user
  else
    env['g']['user'] = nil
  end
end

after do
  # closes db connection after each request
  env['g']['db'].close
end

# ----------------------------
# API Endpoints 
# ----------------------------

# Search API
get "/api/search" do
  q = params["q"]
  language = params["language"] || "en"

  db = connect_db
  db.results_as_hash = true

  @search_results = if q
    # This part correctly handles the search query from the form
    db.execute("SELECT * FROM pages WHERE language = ? AND content LIKE ?", [language, "%#{q}%"])
  else
    []
  end

  db.close

  # This renders the search page with the results
  erb :search
end

# Login (POST)
post "/api/login" do
  username = params["username"]
  password = params["password"]

  db = connect_db
  db.results_as_hash = true
  user = db.execute("SELECT * FROM users WHERE username = ?", username).first
  db.close

  error = nil
  if user.nil?
    error = 'Invalid username'
  elsif !verify_password(user['password'], password)
    error = 'Invalid password'
  else
    # Hvis login er succesfuldt
    session[:user_id] = user['id'] # Vi skal bruge sessions her!

    # Brugeren bliver prompted for at ændre password ved første login efter breach
    if user['must_change_password'].to_i == 1
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

# Register (POST) 
post "/change_password" do
  # Sørg for at brugeren stadig er logget ind
  unless env['g']['user']
    flash[:error] = "Session expired. Please log in again."
    redirect '/login'
  end

  new_pw  = params["new_password"]
  new_pw2 = params["new_password2"]

  if new_pw.to_s.empty? || new_pw != new_pw2
    flash[:error] = "Passwords must match and not be empty"
    redirect '/change_password'
  else
    begin
      db = connect_db
      hashed = BCrypt::Password.create(new_pw)
      db.execute(
        "UPDATE users SET password = ?, must_change_password = 0 WHERE id = ?",
        [hashed, env['g']['user']['id']]
      )
      db.close

      flash[:success] = "Password updated successfully!"
      redirect '/api/search?q='
    rescue => e
      warn "[change_password] ERROR: #{e.class} - #{e.message}"
      flash[:error] = "An unexpected error occurred: #{e.message}"
      redirect '/change_password'
    end
  end
end

# Register (POST) this endpoint process' data from the register formular
# updated with bcrypt
post "/api/register" do
  # --- Tillad både form-data og JSON body ---
  request.body.rewind
  raw_body = request.body.read

  content_type_hdr = request.media_type || request.content_type # begge virker i Sinatra
  is_json_ct = content_type_hdr && content_type_hdr.downcase.include?("application/json")

  first_char = raw_body.lstrip[0]
  looks_like_json = !raw_body.to_s.strip.empty? && ['{', '['].include?(first_char)

  if (is_json_ct || looks_like_json) && !raw_body.to_s.strip.empty?
    begin
      data = JSON.parse(raw_body)
      params.merge!(data) # flet ind i params så resten fungerer som før
      warn "[REGISTER] Parsed JSON body: #{data.inspect}"
    rescue JSON::ParserError
      halt 400, "Invalid JSON payload"
    end
  end

  # --- Herefter fungerer resten som før ---
  username  = params["username"]
  email     = params["email"]
  password  = params["password"]
  password2 = params["password2"]

  warn "[REGISTER] Incoming params: #{params.inspect}"

  # Validation
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
    db = connect_db
    user_exists  = db.execute("SELECT COUNT(*) FROM users WHERE username = ?", username).first[0] > 0
    email_exists = db.execute("SELECT COUNT(*) FROM users WHERE email = ?", email).first[0] > 0
    db.close

    if user_exists
      error = 'The username is already taken'
    elsif email_exists
      error = 'The email is already registered'
    end
  end

  if error
    if is_json_ct
      # --- JSON: send klar fejlrespons ---
      status 409 # Conflict
      content_type :json
      return json(success: false, error: error)
    else
      # --- Form: vis flash og redirect ---
      flash[:error] = error
      redirect '/register'
    end
  else
    begin
      hashed_password = BCrypt::Password.create(password)
      db = connect_db
      db.execute("INSERT INTO users (username, email, password, must_change_password)
                  VALUES (?, ?, ?, ?)", [username, email, hashed_password, 0])
      new_user_id = db.last_insert_row_id
      db.close

      session[:user_id] = new_user_id
      warn "[REGISTER] Created user #{username} (ID=#{new_user_id})"
      redirect '/'
    rescue => e
      warn "[REGISTER] ERROR: #{e.class} - #{e.message}"
      flash[:error] = "Could not register user: #{e.message}"
      redirect '/register'
    end
  end
end

# Logout
get "/api/logout" do
  session.clear # removes all session data, also user_id
  flash[:info] = "Thank you for now. Log in again to continue searching and get the most out of the application."
  redirect '/login'
end

# About page
get "/about" do
  erb :about
end

# Login page
get "/login" do
  erb :login
end

get "/change_password" do
  redirect '/login' unless env['g']['user'] # skal være logget ind
  erb :change_password
end

# Register page, this one only shows the reg formular
get "/register" do
  erb :register
end

# ----------------------------
# debug route ifm redirect problemer ved deploy med reverse proxy
# ----------------------------

get "/debug/headers" do
  content_type "text/html"
  env.select { |k, v| k.start_with?("HTTP_") }
     .map { |k, v| "#{k}: #{v}" }
     .join("<br>")
end


# ----------------------------
# NEW: Weather Endpoints
# ----------------------------

CACHE = {
  weather: {}, # saves data per city
  expires_at: {},  # fresh-ttl
  stale_until: {}  # max expire 
}

# Helper method to fetch weather data from the external service
def get_weather_data(city, ttl: 300, stale_until: 36000)
  now = Time.now
  city_key = city.downcase

  # tjek om der findes frisk cache data (indenfor ttl) → brug den
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

      # Gem i cache med TTL
      CACHE[:weather][city_key]   = data
      CACHE[:expires_at][city_key] = now + ttl
      CACHE[:stale_until][city_key] = now + stale_until

      return { data: data, status: :fresh }
    else
      # Fallback if API fails 
      if CACHE[:weather][city_key] && CACHE[:stale_until][city_key] > now
        return { data: CACHE[:weather][city_key], status: :stale }
      else
        return nil
      end
    end
  rescue StandardError => e
    warn "[weather] error for #{city}: #{e.class} #{e.message}"
    if CACHE[:weather][city_key] && CACHE[:stale_until][city_key] > now
      return { data: CACHE[:weather][city_key], status: :stale }
    else
      return nil
    end
  end
end

# Endpoint 1: API endpoint that returns JSON data

get "/api/weather" do
  city = params['city'] || "Copenhagen"
  result = get_weather_data(city)

  if result
    content_type :json
    json(
      city: city,
      cached: result[:cached],
      data: result[:data]
    )
  else
    status 502
    json(error: "Couldn't fetch weather data for:  #{city}")
  end
end

# Endpoint 2: User-facing page that renders an HTML forecast

get "/weather" do
  @city = params["city"] || "Copenhagen"
  result = get_weather_data(@city)

  if result
    @current_condition = result[:data]["current_condition"][0]
    @forecast = result[:data]["weather"]
    @status   = result[:status] # :fresh eller :stale
    erb :weather
  else
    @error = "Kunne ikke hente vejrdata for #{@city}"
    erb :weather
  end
end


# ----------------------------
# Security Functions
# ----------------------------

def hash_password(password)
  BCrypt::Password.create(password)
end


def verify_password(stored_hash, password)
  BCrypt::Password.new(stored_hash) == password
rescue BCrypt::Errors::InvalidHash
  false # Håndter tilfælde, hvor hashen er ugyldig
end


# ----------------------------
# Start server
# ----------------------------
# NB: I "classic style" Sinatra behøver du ikke run!,
# men du kan lade linjen stå, så virker det i modular style.

# run! if __FILE__ == $0