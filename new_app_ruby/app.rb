# app.rb
require "sinatra"
require "sinatra/json"
require "yaml"
require "json"

# ----------------------------
# Server konfiguration
# ----------------------------
set :port, 8080
set :bind, "0.0.0.0"

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
# API Endpoints (skeletons)
# ----------------------------

# Search API
get "/api/search" do
  q = params["q"]
  language = params["language"] || "en"
  # TODO: slå op i DB
  json(search_results: [], query: q, language: language)
end

# Login (POST)
post "/api/login" do
  username = params["username"]
  password = params["password"]
  # TODO: valider bruger
  json(message: "Login endpoint not implemented", username: username)
end

# Register (POST)
post "/api/register" do
  username = params["username"]
  email = params["email"]
  password = params["password"]
  # TODO: opret bruger i DB
  json(message: "Register endpoint not implemented", username: username, email: email)
end

# Logout
get "/api/logout" do
  # TODO: clear session
  json(message: "Logout endpoint not implemented")
end

# About page
get "/about" do
  "About page (HTML-rendering kan laves senere)"
end

# Login page
get "/login" do
  "Login page (HTML-rendering kan laves senere)"
end

# Register page
get "/register" do
  "Register page (HTML-rendering kan laves senere)"
end

# ----------------------------
# Start server
# ----------------------------
# NB: I "classic style" Sinatra behøver du ikke run!,
# men du kan lade linjen stå, så virker det i modular style.
# run! if __FILE__ == $0
