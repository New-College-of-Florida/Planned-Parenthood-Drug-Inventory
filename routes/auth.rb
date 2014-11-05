require 'pony'
require 'warden'
require 'securerandom' #uuid stuff
require 'date' #uuid stuff

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

  get '/auth/reset' do
    send_file File.join('public', 'reset.html')
  end
  
  post '/auth/reset' do
    puts "Sending an email to #{params[:email]}..."
    # gets 12 pseudorandom characters in the ASCII A-Z + symbols + a-z range 
		begin
	    user =  User.first(:email => params[:email]) #try to find the user
		rescue #whoops, no such email exists
			fail!("No user found for that email. Please try again.")
		end
		if not user.uuid_date or user.uuid_date < Date.now
			new_uuid = SecureRandom.uuid
			user.update({ :uuid_token => new_uuid, :uuid_date => Date.now })
		end
#    arf =(0...12).map { (65 + rand(56)).chr }.join
#    user.update({ :password => arf })
    Pony.mail({
	    :to => params[:email],
	    :subject => "Please reset your password for the Planned Parenthood Drug Inventory Databse",
	    :body => "You, or someone claiming to be you, has asked to reset your password. Please go to http://localhost:drugdbport/auth/change/#{new_uuid} to change your password.", #TODO: Change localhost:whatever to our actual URL
	    :via => :sendmail
	  })
  end

	get '/auth/change/:uuid' do
		begin
			user = User.first(:uuid_token => params[:uuid])
		rescue #you gave an invalid one...
			fail!("The link you provided is either invalid or has expired. If you intended to reset your password and have input this link correctly, please try to reset it again.")
		end
		#TODO: Find out how to subtract dates so we can say "UUID less than a week old" or whatever
		#cool, so yours is valid. Display change form...we make it a template so it has the correct links
		@uuid = params[:uuid]
		erb :change
	end

	post '/auth/change/:uuid' do
		begin
			user = User.first(:uuid_token => params[:uuid]) #check again just in case
		rescue
			fail!("The UUID you have provided is no longer valid. Please try to reset your password again using our automated system.")
		end
		#we do the password matching check in JS, not on the server.
		#now take the new password and shove it in to user
		user.update({:password => params[:new_password]})
		"Password updated successfully!"
	end


end
