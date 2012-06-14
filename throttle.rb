class Throttle
  def initialize(maximum, seconds)
    @mutex = Mutex.new
    @maximum = maximum
    @seconds = seconds
    start_reference
  end

  def reference_time_expired?
    Time.now - @reference_time > @seconds
  end

  def start_reference
    @reference_time = Time.now
    @registration_count = 0
  end

  def release_time
    @reference_time + @seconds
  end

  def seconds_until_release
    time = release_time - @reference_time
    time < 0 ? 0 : time
  end

  def try_register
    if @reference_time.nil? || reference_time_expired?
      start_reference
      true
    elsif @registration_count >= @maximum
      puts "THROTTLING FOR #{seconds_until_release} seconds because of #{@registration_count} holds"
      sleep seconds_until_release
      false
    else
      @mutex.synchronize { @registration_count += 1 }
      true
    end
  end

  def register
    loop { return true if try_register }
  end
end