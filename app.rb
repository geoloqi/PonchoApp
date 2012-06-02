require 'bundler/setup'
Bundler.require

configure do
  @darksky = Darksky::API.new ENV['DARKSKY_KEY']
end

get '/' do
  'This is the Location Barometer service. You should not need to access it directly.'
end

post '/callback' do
  
end