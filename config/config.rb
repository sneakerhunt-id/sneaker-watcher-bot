require 'redis'
require 'logstash-logger'

module SneakerWatcherBot
  def self.redis
    @redis ||= Redis.new(
      host: ENV['REDIS_HOST'], 
      port: ENV['REDIS_PORT'], 
      password: ENV['REDIS_PASSWORD'].presence
    )
  end

  def self.logger
    LogStashLogger.new(
      type: :stdout,
      format: :json_lines
    )
  end
end
