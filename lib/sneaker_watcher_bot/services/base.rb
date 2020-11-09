module Services
  class Base
    def self.call(*args, &block)
      new(*args, &block).call
    end

    def self.interval_seconds
      # run every 30 seconds by default
      (ENV['DEFAULT_SCRAPER_INTERVAL_SECONDS'] || 30).to_i
    end

    def self.klass_tag
      self.name.split('::').map(&:underscore)
    end

    def call
      ::Metric.measure(klass_tag) { perform }
    end

    def perform
      raise NotImplementedError, 'You must implement `perform`.'
    end

    private

    def klass_tag
      self.class.name.split('::').map(&:underscore)
    end
  end
end
