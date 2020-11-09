class EndlessLoop
  class << self
    def perform(interval_seconds)
      while true do
        start_time = Time.now
        yield
        latency = (Time.now - start_time).round
        sleep_duration = [interval_seconds - latency, 0].max
        sleep(sleep_duration) if sleep_duration > 0
      end
    end
  end
end
