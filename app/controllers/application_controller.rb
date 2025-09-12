# These require statements MUST come before the class definition.
require 'sinatra/base'
require 'sinatra/activerecord'
require 'sinatra/flash'
require_relative '../models/user'
require_relative '../models/page'

class ApplicationController < Sinatra::Base
  # Configuration
  configure do
    set :views, 'app/views'
    set :public_folder, 'public'
    enable :sessions
    set :session_secret, "development key" # Use ENV['SESSION_SECRET'] in production

    # This line tells Rake where to find your migrations
    ActiveRecord::Migrator.migrations_paths = [File.expand_path('../../db/migrate', __FILE__)]
  end

  register Sinatra::Flash

  # Database configuration
  set :database_file, '../../config/database.yml'

  # Helper methods
  helpers do
    def current_user
      @current_user ||= User.find(session[:user_id]) if session[:user_id]
    end

    def logged_in?
      !!current_user
    end
  end

  # Page Routes
  get '/' do
    @search_results = []
    if params[:q] && !params[:q].empty?
      # Use parameterized queries to prevent SQL injection
      query = "%#{params[:q]}%"
      @search_results = Page.where("content LIKE ?", query)
    end
    erb :search
  end

  get '/about' do
    erb :about
  end

  # Authentication Routes (Display Forms)
  get '/login' do
    redirect '/' if logged_in?
    erb :login
  end

  get '/register' do
    redirect '/' if logged_in?
    @user = User.new
    erb :register
  end

  # Authentication Routes (Handle Form Submissions)
  post '/login' do
    user = User.find_by(username: params[:username])

    if user && user.authenticate(params[:password])
      session[:user_id] = user.id
      flash[:notice] = 'You were logged in'
      redirect '/'
    else
      @error = 'Invalid username or password'
      erb :login
    end
  end

  post '/register' do
    # 'password_confirmation' is automatically used by has_secure_password
    @user = User.new(
      username: params[:username],
      email: params[:email],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )

    if @user.save
      flash[:notice] = 'You were successfully registered and can login now'
      redirect '/login'
    else
      # Pass the user object with errors back to the view
      @error = @user.errors
      erb :register
    end
  end

  get '/logout' do
    session.clear
    flash[:notice] = 'You were logged out'
    redirect '/'
  end
end