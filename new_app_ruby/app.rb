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
  "Sinatra + OpenAPI demo! Besøg /docs for Swagger UI"
end

# ----------------------------
# Request Handlers
# ----------------------------

before do
  # Global variabel to contain data
  env['g'] ||= {}
  env['g']['db'] = connect_db

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
  elsif not verify_password(user['password'], password)
    error = 'Invalid password'
  else
    # Hvis login er succesfuldt
    session[:user_id] = user['id'] # Vi skal bruge sessions her!
    #json(message: "You were logged in", user_id: user['id'])

    redirect 'api/search?q='
  end

  if error
    json(error: error)
  end
end

# Register (POST) this endpoint process' data from the register formular
# updated with bcrypt
post "/api/register" do
  username = params["username"]
  email = params["email"]
  password = params["password"]
  password2 = params["password2"]

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
    # Tjek om brugernavnet allerede er taget
    user_exists = db.execute("SELECT COUNT(*) FROM users WHERE username = ?", username).first[0] > 0
    db.close

    if user_exists
      error = 'The username is already taken'
    end
  end

  if error
    # Hvis der er en fejl, viser vi registreringssiden igen med en fejlbesked
    @error = error
    erb :register
  else
    hashed_password = BCrypt::Password.create(password)
    db = connect_db
    db.execute("INSERT INTO users (username, email, password) values (?, ?, ?)", [username, email, hashed_password])
    db.close
    # Succesfuld registrering, omdiriger til login-siden
    redirect 'login'
  end
end

# Logout
get "/api/logout" do
  session.clear # removes all session data, also user_id
  json(message: "You were logged out")
end

# About page
get "/about" do
  erb :about
end

# Login page
get "/login" do
  erb :login
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
