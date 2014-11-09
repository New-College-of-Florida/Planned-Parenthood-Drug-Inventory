#!/usr/bin/env ruby

# dependencies
require 'sinatra'
require 'sinatra/content_for'
require 'active_record'
require 'chartkick'
require 'warden'

# init models
require './models/init'

# routes 
require './routes/auth'
require './routes/email'
require './routes/account'
require './routes/corrections'
require './routes/display' #for charts

module SST
  class App < Sinatra::Base
    enable :sessions

    # middleware
    use Auth
    use Emails
    use Accounts
    use DrugDisplay
    #use Graphs # TODO : impliment this
    #use Display

    get '/' do
      env['warden'].authenticate!
      erb :main
    end
  end
end
