class Metric
  class << self
    def measure(klass_tag, labels = {})
      start_time = Time.now
      status = 'success'
      begin
        yield
      rescue StandardError => e
        status = 'fail'
        raise e
      ensure
        duration = Time.now - start_time
        log_object = {
          tags: klass_tag,
          labels: labels,
          status: status,
          latency: duration
        }
        if status == 'success'
          log_object[:message] = "#{klass_tag.join('_')} performed successfully"
          SneakerWatcherBot.logger.info(log_object)
        else
          log_object[:message] = e.message
          log_object[:backtrace] = e.backtrace.take(5)
          SneakerWatcherBot.logger.error(log_object)
        end
      end
    end
  end
end
