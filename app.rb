require 'yaml'
require 'bundler/setup'
Bundler.require

def darksky
  @darksky ||= Darksky::API.new(Config.darksky_key)
end

def darksky_forecast(lat, lng)
  Hashie::Mash.new darksky.brief_forecast lat, lng
end

def load_geoloqi_users
  users = Geoloqi::Session.new.app_get('user/list', limit: 0).users
  Mutex.new.synchronize { $users = users }
end

def process_users
  $users.each do |user|
    l = Geoloqi::Session.new(access_token: $geoloqi_app_token).get 'location/last', user_id: user.user_id
    f = Hashie::Mash.new darksky_forecast(l.location.position.latitude, l.location.position.longitude)

    if user.extra.hour_summary.nil?
      Geoloqi::Session.new.app_post "user/update/#{user.user_id}", extra: {hour_summary: 'clear'}
    end

    if f.hourSummary != 'clear' && user.extra.hour_summary != f.hourSummary
      Geoloqi::Session.new.app_post "user/update/#{user.user_id}", extra: {hour_summary: f.hourSummary}
      Geoloqi::Session.new.post 'message/send', user_id: user.user_id, text: user.extra.hour_summary
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
    Config = Hashie::Mash.new YAML.load_file('./config.yml')
  else
    Config = Hashie::Mash.new({
      geoloqi_app_id:     ENV['GEOLOQI_APP_ID'],
      geoloqi_app_secret: ENV['GEOLOQI_APP_SECRET'],
      darksky_key:        ENV['DARKSKY_KEY']
    })
  end

  Geoloqi.config client_id: Config.geoloqi_app_id, client_secret: Config.geoloqi_app_secret, use_hashie_mash: true

  $geoloqi_app_token = Geoloqi::Session.new.application_access_token
  load_geoloqi_users
  process_users

  Scheduler = Rufus::Scheduler.start_new

  Scheduler.every '5m' do
    load_geoloqi_users
    process_users
  end
end

before do
  @geoloqi = Geoloqi::Session.new
end

get '/' do
  'This is the Location Barometer service. You should not need to access it directly.'
end