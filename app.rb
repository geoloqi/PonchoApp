require 'yaml'
require 'bundler/setup'
Bundler.require

configure do
  if File.exist?('./config.yml')
    Config = Hashie::Mash.new YAML.load_file('./config.yml')
  else
    Config = Hashie::Mash.new({
      geoloqi_app_id:     ENV['GEOLOQI_APP_ID'],
      geoloqi_app_secret: ENV['GEOLOQI_APP_SECRET'],
      darksky_key:        ENV['DARKSKY_KEY']
    })
  end

  Scheduler = Rufus::Scheduler.start_new

  Geoloqi.config client_id: Config.geoloqi_app_id, client_secret: Config.geoloqi_app_secret
end

before do
  @geoloqi = Geoloqi::Session.new
end

get '/' do
  'This is the Location Barometer service. You should not need to access it directly.'
end

post '/users' do
  Users ||= {}
end


post '/callback' do
  binding.pry
  darksky.brief_forecast('45.52','-122.681944').inspect
  
  scheduler.cron '0 22 * * 1-5' do
      # every day of the week at 22:00 (10pm)
    end
  
  
end

def darksky
  @darksky ||= Hashie::Mash.new Darksky::API.new(Config.darksky_key)
end