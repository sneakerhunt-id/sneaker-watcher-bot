module Services
  class Base
    def self.call(*args, &block)
      new(*args, &block).call
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
