require 'redis'

module AtmosIdBot
  def self.redis
    @redis ||= Redis.new(
      host: ENV['REDIS_HOST'], 
      port: ENV['REDIS_PORT'], 
      password: ENV['REDIS_PASSWORD'].presence
    )
  end
end
