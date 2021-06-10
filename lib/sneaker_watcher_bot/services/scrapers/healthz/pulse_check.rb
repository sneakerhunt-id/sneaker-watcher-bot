module Service
  module Scraper
    module Healthz
      class PulseCheck < Base
        INTERVAL_SECONDS = (ENV['HEALTHZ_PULSE_CHECK_INTERVAL_SECONDS'] || 3600).to_i
        
        def self.interval_seconds
          INTERVAL_SECONDS
        end

        def perform
          message = "HEALTH CHECK - CHECK THE PRODUCTION SERVER IF THIS STOPS REPEATING EVERY #{INTERVAL_SECONDS} SECONDS"
          TelegramBot.new(ENV['TELEGRAM_PRODUCTION_SUPPORT_CHAT_ID']).send_telegram_message(message)
        end
      end
    end
  end
end
