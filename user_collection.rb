class UserCollection
  THREAD_QUEUE_SIZE = 30
  DARKSKY_RATE_LIMIT_MAXIMUM = 6
  DARKSKY_RATE_LIMIT_INTERVAL = 9

  def initialize
    @throttle = Throttle.new DARKSKY_RATE_LIMIT_MAXIMUM, DARKSKY_RATE_LIMIT_INTERVAL
    @users = []
    @queue = Queue.new
    THREAD_QUEUE_SIZE.times do |num|
      @queue << num
    end
  end

  def add(user)
    @users << user unless user_exists?(user)
  end

  def remove(user)
    @users.delete_if { |u| u.user_id == user.user_id }
  end

  def user_exists?(user)
    !@users.select {|u| u.user_id == user.user_id}.first.nil?
  end

  def update
    new_users = User.all
    new_users.each { |new_user| add(new_user) }
  end

  def perform_forecast
    puts "Updating user list.."
    update

    puts "Starting forecasting for #{@users.length} people"

    threads = []

    @users.each do |user|
      next if user.forecast_expired?
      token = @queue.pop

      threads << Thread.new {
        user.update_location
        @queue.push token
      }
    end

    threads.each {|t| t.join}

    @users.each do |user|
      next if user.forecast_expired?
      @throttle.register
      token = @queue.pop

      threads << Thread.new {
        user.perform_forecast
        @queue.push token
      }
    end

    puts "Done queueing threads for user forecast updates"
  end
end