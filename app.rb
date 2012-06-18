require 'yaml'
require 'bundler/setup'
require_relative './user'
require_relative './user_collection'
require_relative './throttle'
Bundler.require

# Don't try this at home, kids
module Kernel
  alias_method :puts_original, :puts
  MUTEX = Mutex.new
  def puts(text)
    MUTEX.synchronize { puts_original(text) }
  end
end

configure do
  if File.exist?('./config.yml')
    AppConfig = Hashie::Mash.new YAML.load_file('./config.yml')
  else
    AppConfig = Hashie::Mash.new({
      geoloqi_app_id:     ENV['GEOLOQI_APP_ID'],
      geoloqi_app_secret: ENV['GEOLOQI_APP_SECRET'],
      geoloqi_layer_id:   ENV['GEOLOQI_LAYER_ID'],
      darksky_key:        ENV['DARKSKY_KEY'],
      ga_id:              ENV['GA_ID']
    })
  end

  Geoloqi.config client_id: AppConfig.geoloqi_app_id, client_secret: AppConfig.geoloqi_app_secret, use_hashie_mash: true

  PonchoSession = Geoloqi::Session.new
  Users         = UserCollection.new

  Scheduler = Rufus::Scheduler.start_new

  Scheduler.every '5m' do
    puts "5 minutes are up!!! Cycling the user list and checking for required updates"
    Users.perform_forecast
  end

  Thread.new {
    Users.perform_forecast
  }
end

before do
  @geoloqi = Geoloqi::Session.new
end

get '/' do
  erb :index
end

get '/app' do
  File.read('./public/app/index.html')
end
