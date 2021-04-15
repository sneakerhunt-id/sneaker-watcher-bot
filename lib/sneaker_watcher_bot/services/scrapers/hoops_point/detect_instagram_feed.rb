module Service
  module Scraper
    module HoopsPoint
      class DetectInstagramFeed < Base
        include ::InstagramHelper

        def self.interval_seconds
          (ENV['HOOPS_POINT_INSTAGRAM_FEED_INTERVAL_SECONDS'] || 10).to_i
        end

        def perform
          username, password = set_instagram_account
          feeds = scrape_feeds(target_instagram_username, username, password, 6)
          feeds.each do |feed|
            if fcfs?(feed[:text])
              message_title = "FCFS"
            elsif raffle?(feed[:text])
              message_title = "RAFFLE"
            else
              next
            end

            if new_feed?(feed)
              key = redis_key(feed[:id])
              message = "<strong>HOOPS POINT INSTAGRAM FEED #{message_title} UPDATE DETECTED!</strong>\n"\
                "<a href='#{feed[:url]}'>CHECK IT OUT!</a>"
              message += append_additional_info
              TelegramBot.new.send_telegram_photo(message, feed[:image])
              SneakerWatcherBot.redis.set(key, feed.to_json)
              SneakerWatcherBot.redis.expireat(key, redis_expiry.to_i)
            end
          end
        end

        def new_feed?(feed_hash)
          key = redis_key(feed_hash[:id])
          feed_cache = SneakerWatcherBot.redis.get(key)
          return true if feed_cache.blank?
          SneakerWatcherBot.redis.expireat(key, redis_expiry.to_i)
          return false
        end

        private

        def append_additional_info
          additional_message = "\n\n<strong>IMPORTANT LINKS</strong>:"\
            "\n<a href='#{whatsapp_link('6281953597487')}'>WHATSAPP KOTA KASABLANKA JAKARTA</a>"\
            "\n<a href='#{whatsapp_link('6287877296526')}'>WHATSAPP PACIFIC PLACE JAKARTA</a>"\
            "\n<a href='#{whatsapp_link('6287877190777')}'>WHATSAPP PIM2 JAKARTA</a>"\
            "\n<a href='#{whatsapp_link('6287737816066')}'>WHATSAPP PARIS VAN JAVA BANDUNG</a>"\
        end

        def whatsapp_link(phone_number)
          "https://wa.me/#{phone_number}?text=Nama:+Alamat:+Size:"
        end

        def redis_key(identifier)
          "hoops_point_instagram_feed_#{identifier}"
        end

        def target_instagram_username
          ENV['HOOPS_POINT_INSTAGRAM_USERNAME']
        end

        def redis_expiry
          Time.now + 1.hours
        end
      end
    end
  end
end