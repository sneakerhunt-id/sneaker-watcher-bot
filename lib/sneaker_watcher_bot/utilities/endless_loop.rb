class EndlessLoop
  class << self
    def perform(interval_seconds, background_name)
      while true do
        start_time = Time.now
        yield
        latency = (Time.now - start_time).round
        sleep_duration = [interval_seconds - latency, 0].max
        if sleep_duration > 0
          log_object = {
            message: "#{background_name} with interval of #{interval_seconds} will re-run in #{sleep_duration} seconds",
            interval_seconds: interval_seconds,
            background_name: background_name
          }
          SneakerWatcherBot.logger.info(log_object)
          sleep(sleep_duration)
        end
      end
    end
  end
end
