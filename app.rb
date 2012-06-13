require 'yaml'
require 'bundler/setup'
require_relative './user'
Bundler.require

def load_geoloqi_users
  binding.pry
  users = User.all
end

def process_users
  $users.each do |user|
    begin
      sleep 10

      f = Hashie::Mash.new darksky_forecast(l.location.position.latitude, l.location.position.longitude)

      if user.extra.hour_summary.nil?
        Geoloqi::Session.new.app_post "user/update/#{user.user_id}", extra: {hour_summary: 'clear'}
      end

      if !f.hourSummary.nil? && !f.hourSummary.empty? && f.hourSummary != 'clear' && user.extra.hour_summary != f.hourSummary
        Geoloqi::Session.new.app_post "user/update/#{user.user_id}", extra: {hour_summary: f.hourSummary}
        Geoloqi::Session.new(access_token: $geoloqi_app_token).post 'message/send', user_id: user.user_id, layer_id: AppConfig.geoloqi_layer_id, text: f.hourSummary
      end
    rescue Geoloqi::ApiError
      # Don't do anything if there is no recent location from a user
    end
  end
end

=begin
{"currentTemp"=>61,
 "currentSummary"=>"clear",
 "hourSummary"=>"clear",
 "isPrecipitating"=>false,
 "minutesUntilChange"=>0,
 "checkTimeout"=>1050}
=end

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

  load_geoloqi_users
  # process_users

  Scheduler = Rufus::Scheduler.start_new

  Scheduler.every '15m' do
    load_geoloqi_users
    process_users
  end
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
