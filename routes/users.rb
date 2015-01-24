require 'securerandom'
require 'pony'

# Invalid UTF-8 sequences in the email file(s) require this soln
require 'iconv' unless String.method_defined?(:encode)

PASSWORDEMAIL = File.join(CONFIG['install_dir'], 'mail/users/password-reset.erb')

#
# User Routes
#
class Users < Sinatra::Base
  set :views, Dir.pwd + '/views'

  # We run into issues with non-valid UTF characters (actually, UTF-16),
  # so we need to transform a string into UTF-8 from UTF-8 to ensure they
  # are rendered and written properly.
  def escape(string)
    if String.method_defined?(:encode)
      string.encode!('UTF-16', 'UTF-8', invalid: :replace, replace: '')
      string.encode!('UTF-8', 'UTF-16')
    else
      ic = Iconv.new('UTF-8', 'UTF-8//IGNORE')
      string = ic.iconv(string)
    end
  end

  # Send a reset email to the user
  def send_reset_email(data)

    # compose the reset URL
    data[:url] = 'http://localhost:#{settings.port}/user/#{data[:user].id}/reset/#{data[:token]}'

    # template the email message
    templateString = File.read(PASSWORDEMAIL)
    template = ERB.new(templateString).result(binding)

    # set the mail server parameters (from config.yaml)
    message_params= {
      from: CONFIG['email']['sender'],
      to: params[:email],
      subject: '[DRUGDB] Password Reset Request',
      html_body: escape(template)
    }

    # if we have specified the 'via' methods for delivery,
    # make sure to pass those to Pony
    if CONFIG['email']['via']
      message_params['via'] = CONFIG['email']['via']
      message_params['via_options'] = CONFIG['email']['via_options']
    end

    # send the email via Pony gem
    Pony.mail(message_params)
  end

  # Ask for a password reset email to be sent

  get '/users/reset/email' do

    # render the password email form
    erb :'users/password-email-form', locals: { error: nil }
  end

  post '/users/reset/email' do

    # get the user from the email
    user = User.first(email: params[:email])

    # if the user does not exist, we need to reload the page,
    # prompting the user to try again.  Otherwise, we send a reset
    # email to the user.
    if user.nil?
      erb :'users/password-email-form', locals: { error: params[:email] }
    else

      # make sure the previous uuid_dat is still valid
      if not user.uuid_date or user.uuid_date < Date.today
        new_uuid = SecureRandom.uuid
        user.update({ uuid_token: new_uuid, uuid_date: Date.today })
      else
        new_uuid = user.uuid_token
      end

      data = { url: url, user: user, email: params[:email], token: new_uuid }
      send_reset_email(data)

      # render a confirmation page
      erb :'users/password-email-sent', locals: { data: data }
    end
  end

  # reset a user's password from an email

  get '/user/:uuid/reset/:token' do
    user = User.first(id: params[:uuid], uuid_token: params[:token])

    # if the user exists, render a new password form
    if not user.nil?
      erb :'users/password-new', locals: { data: { user: user, token: params[:token] } }
    else
      url = 'http://localhost:#{settings.port}/users/reset/email'
      erb :'users/password-token-expired', locals: { data: { url: url } }
    end

  end

  post '/user/:uuid/reset/:token' do
    user = User.first(id: params[:uuid], uuid_token: params[:token])

    # wipe old tokens and set password
    if not user.nil?
      user.update({password: params[:password], uuid_token: nil, uuid_date: nil})
      erb :'users/password-reset-success', locals: { data: { email: user.email } }
    else
      erb :'users/password-reset-failure'
    end
  end

  # functionality to create a new user

  get '/users/create' do
    erb :'users/create'
  end

  post '/users/create' do
    # attempt to create a user

    begin
      user = User.create({ name: params[:name], email: params[:email], password: params[:password], created: Time.now})
      if user.saved?
        erb :'users/create-success', locals: { data: { user: user } }
      else
        throw 'Not saved'
      end
    rescue
      erb :'users/create-error'
    end
  end
end
