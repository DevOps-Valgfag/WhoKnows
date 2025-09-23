require "sinatra"
require "sinatra/json"
require "yaml"
require "json"
require "sqlite3"
require "bcrypt"
require "sinatra/flash"
require "dotenv/load"
require "httparty" # Gem for making HTTP requests

configure do
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
# API Endpoints (skeletons)
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

    redirect '/api/search?q='
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
    # Sørg for at din `users` tabel har en kolonne for `password` der er bred nok til en bcrypt hash (typisk VARCHAR(60))
    db.execute("INSERT INTO users (username, email, password) values (?, ?, ?)", [username, email, hashed_password])
    db.close
    # Succesfuld registrering, omdiriger til login-siden
    redirect '/login'
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
# NEW: Weather Endpoints
# ----------------------------

# Helper method to fetch weather data from the external service
def get_weather_data(city)
  url = "https://wttr.in/#{city}?format=j1"
  response = HTTParty.get(url)
  return nil unless response.code == 200
  JSON.parse(response.body)
end

# Endpoint 1: API endpoint that returns JSON data
# Corresponds to /api/weather in your OpenAPI spec
get "/api/weather" do
  city = params['city'] || "Copenhagen"
  weather_data = get_weather_data(city)

  if weather_data
    # According to your spec, the response should be an object with a "data" key
    json(data: weather_data)
  else
    status 500
    json(error: "Could not fetch weather data")
  end
end

# Endpoint 2: User-facing page that renders an HTML forecast
# Corresponds to /weather in your OpenAPI spec
get "/weather" do
  @city = params['city'] || "Copenhagen"
  weather_data = get_weather_data(@city)

  if weather_data
    @current_condition = weather_data["current_condition"][0]
    @forecast = weather_data["weather"]
    erb :weather
  else
    "Sorry, could not fetch the weather."
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