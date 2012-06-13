class User
  attr_reader :user_id, :hour_summary

  def initialize(user_id, hour_summary)
    @user_id = user_id
    @hour_summary = hour_summary

    persist_hour_summary 'clear' if @hour_summary.nil?
  end

  def persist_hour_summary(text)
    PonchoSession.app_post "user/update/#{@user_id}", extra: {hour_summary: text}
  end

  def update_location
    begin
      s = Geoloqi::Session.new(access_token: PonchoSession.application_access_token)
      resp = s.get('location/last', user_id: @user_id)
      @location = Hashie::Mash.new(lat: resp.location.position.latitude, lng: resp.location.position.longitude)
    rescue Geoloqi::ApiError
      # No recent location when this happens.
    end
  end

  def perform_forecast
    return if @check_timeout_time > Time.now
    update_location
    update_forecast

    if !@forecast.hourSummary.nil? && !@forecast.hourSummary.empty? && @forecast.hourSummary != 'clear' && @hour_summary != @forecast.hourSummary
      @hour_summary = @forecast.hourSummary
      persist_hour_summary @hour_summary
      Geoloqi::Session.new(access_token: PonchoSession.application_access_token).post 'message/send',
                                                                                      user_id:  @user_id,
                                                                                      layer_id: AppConfig.geoloqi_layer_id,
                                                                                      text:     @hour_summary
    end
  end

  def update_forecast
    @forecast = Hashie::Mash.new Darksky::API.new(AppConfig.darksky_key).brief_forecast(@location.lat, @location.lng)
    @check_timeout_time = Time.now + @forecast.checkTimeout
  end

  def self.all
    PonchoSession.app_get('user/list', limit: 0).users.collect do |geoloqi_user|
      new geoloqi_user.user_id, geoloqi_user.extra.hour_summary
    end
  end
end