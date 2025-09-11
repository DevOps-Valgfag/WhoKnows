require 'sinatra'
# The 'if development?' block ensures this only runs on your local machine
if development?
  require 'sinatra/reloader'
end

get '/' do
  'Hello from my first Sinatra app on Windows!'
end