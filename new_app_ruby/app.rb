# app.rb
require "sinatra"
require "sinatra/json"
require "json"

# Indlæs OpenAPI spec fra YAML-fil
require "yaml"

SPEC_FILE = File.expand_path("openapi.yaml", __dir__)
OPENAPI_SPEC = YAML.load_file(SPEC_FILE)

# Et endpoint til at serve selve YAML-filen (så Swagger UI kan hente den)
get "/openapi.yaml" do
  content_type "application/yaml"
  File.read(SPEC_FILE)
end

# Eventuelt kan du også expose JSON-versionen
get "/openapi.json" do
  content_type :json
  JSON.pretty_generate(OPENAPI_SPEC)
end
