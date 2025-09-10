# app.rb
require 'sinatra'
require 'sinatra/reloader' if development? # Auto-reloads on changes

# A simple test route
get '/' do
  'Hello from Sinatra!'
end