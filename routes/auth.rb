require 'pony'
require 'warden'
require 'securerandom'

class Auth < Sinatra::Base

  #
  # Warden Configuration
  #

  use Warden::Manager do |config|
    # serialize user to session ->
    config.serialize_into_session{|user| user.id}
    # serialize user from session <-
    config.serialize_from_session{|id| User.get(id)}
    # configuring strategies
    config.scope_defaults :default,
                  strategies: [:password],
                  action: 'auth/unauthenticated'
    config.failure_app = self
  end

  Warden::Manager.before_failure do |env,opts|
    env['REQUEST_METHOD'] = 'POST'
  end

  Warden::Strategies.add(:password) do
    # valid params for authentication
    def valid?
      params['username'] && params['password']
    end

    # authenticating a user
    def authenticate!
      # find for user
      user = User.first(name: params['username'])
      if user.nil?
          puts "[AUTH] No user!"
          fail!("Invalid credentials: user does not exist.")
      elsif user.authenticate(params['password'])
        puts "[AUTH] Login success!"
        success!(user)
      else
        puts "[AUTH] Login error!"
        fail!("An error occurred.  Please try again.")
      end
    end
  end

  #
  # Authenication Routes
  #

  # Login form submits here.
  post '/auth/login' do
    env['warden'].authenticate!
    if session[:return_to].nil?
      redirect '/'
    else
      redirect session[:return_to]
    end
  end

  # when a user reaches a protected route watched by Warden calls
   post '/auth/unauthenticated' do
     session[:return_to] = env['warden.options'][:attempted_path] if session[:return_to].nil?
     puts env['warden.options'][:attempted_path]
     puts env['warden']
     redirect '/login.html'
   end

  get '/auth/logout' do 
    env['warden'].raw_session.inspect
    env['warden'].logout
    redirect '/'
  end
end
