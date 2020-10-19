module Services
  class Base
    def self.call(*args, &block)
      new(*args, &block).call
    end

    def call
      raise NotImplementedError, 'You must implement `call`.'
    end
  end
end
