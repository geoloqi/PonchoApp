class User
  attr_reader :user_id, :hour_summary

  def initialize(user_id, hour_summary, check_timeout)
    check_timeout_time = nil
    check_timeout_time = (check_timeout.is_a?(Time) ? check_timeout : Time.at(check_timeout.to_i)) unless check_timeout.nil?

    @user_id = user_id

    if hour_summary.nil? && check_timeout_time.nil?
      @current_forecast = {hour_summary: 'clear', check_timeout_time: 0}
      persist 'clear', 0
    else
      @current_forecast = Hashie::Mash.new(hour_summary: hour_summary, check_timeout_time: check_timeout_time)
    end
  end

  def persist(hour_summary=nil, check_timeout_time=nil)
    extra = {}
    extra[:hour_summary] = hour_summary if hour_summary
    extra[:check_timeout_time] = check_timeout_time.to_i if check_timeout_time

    PonchoSession.app_post "user/update/#{@user_id}", extra: extra
  end

  # Could be used to collect users that are expired, currently the ones that don't need to be checked clog up the throttle.
  def forecast_expired?
    @location.nil? || @current_forecast.nil? || (!@current_forecast.check_timeout_time.nil? && @current_forecast.check_timeout_time < Time.now)
  end

  def update_location
    begin
      s = Geoloqi::Session.new(access_token: PonchoSession.application_access_token)
      resp = s.get('location/last', user_id: @user_id)
      @location = Hashie::Mash.new(lat: resp.location.position.latitude, lng: resp.location.position.longitude)
    rescue Geoloqi::ApiError => e
      if e.message =~ /user has no recent location/
        @location = nil
      else
        fail
      end
      # No recent location when this happens.
    end
  end

  def perform_forecast
    return false if @current_forecast && !@current_forecast.check_timeout_time.nil? && @current_forecast.check_timeout_time > Time.now
    # update_location <- doing this before the throttle to reduce loop wait slowdown
    return if @location.nil?
    f = get_forecast
    return if f.nil?

    if !f.hour_summary.nil? && !f.hour_summary.empty? && @current_forecast.hour_summary != f.hour_summary
      
      puts "On user #{@user_id}, we changed to #{f.hour_summary} from #{@current_forecast.hour_summary}, updating.."
      @current_forecast = Hashie::Mash.new(hour_summary: f.hour_summary, check_timeout_time: f.check_timeout_time)
      persist @current_forecast.hour_summary, @current_forecast.check_timeout_time

      # We don't really need to report this
      return true if @current_forecast.hour_summary == 'clear'

      s = Geoloqi::Session.new(access_token: PonchoSession.application_access_token)
      puts "SENDING MESSAGE TO #{@user_id}: #{@current_forecast.hour_summary}"

      s.post 'message/send',
             user_id:  @user_id,
             layer_id: AppConfig.geoloqi_layer_id,
             text:     @current_forecast.hour_summary
    end
  end

  def get_forecast
    begin
      resp = RestClient.get "https://api.darkskyapp.com/v1/brief_forecast/#{AppConfig.darksky_key}/#{@location.lat},#{@location.lng}"
    rescue RestClient::Gone
      puts "User #{@user_id} is not in the forecast area (#{@location.lat}, #{@location.lng})"
      return
    rescue RestClient::RequestFailed => e
      if e.message =~ /HTTP status code 429/
        puts "Hit rate limit unexpectedly, sleeping #{@user_id} update for full limit interval"
        sleep UserCollection::DARKSKY_RATE_LIMIT_INTERVAL
      end
    end
    if resp.nil?
      puts "Got nothing back for #{@user_id}. We'll try again on the next cycle.."
      return
    end
    
    f = MultiJson.decode resp, symbolize_keys: true

    Hashie::Mash.new(hour_summary: f[:hourSummary], check_timeout_time: (Time.now + f[:checkTimeout]))
  end

  def self.all
    PonchoSession.app_get('user/list', limit: 0).users.collect do |geoloqi_user|
      new geoloqi_user.user_id, geoloqi_user.extra.hour_summary, geoloqi_user.extra.check_timeout
    end
  end
end