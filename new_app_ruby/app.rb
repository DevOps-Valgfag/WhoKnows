# app.rb
require "sinatra"
require "sinatra/json"
require "yaml"
require "json"
require "sqlite3"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, "development key" # SKAL ændres til en stærk, hemmelig nøgle i produktion!
end

# ----------------------------
# Server konfiguration
# ----------------------------
set :port, 8080
set :bind, "0.0.0.0"


# ----------------------------
# Database path
# ----------------------------
DB_PATH = File.expand_path("../whoknows.db",__FILE__)

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

# Swagger UI
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
    db.execute("SELECT * FROM pages WHERE language = ? AND content LIKE ?", [language, "%#{q}%"])
  else
    []
  end

  db.close

  erb :search, locals: { query: q }
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
    json(message: "You were logged in", user_id: user['id'])
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
 
  # Validering
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
    json(error: error)
  else
    hashed_password = hash_password(password)

    db = connect_db
    # Sørg for at din `users` tabel har en kolonne for `password` der er bred nok til en bcrypt hash (typisk VARCHAR(60))
    db.execute("INSERT INTO users (username, email, password) values (?, ?, ?)", [username, email, hashed_password])
    db.close

    json(message: "You were successfully registered and can login now")
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
