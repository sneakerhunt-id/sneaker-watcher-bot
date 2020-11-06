module Service
  module Scraper
    module Atmos
      class DetectInstagramStoryCta < Base
        def perform
          stories = InstagramScraper.new.get_stories(instagram_username)
          stories.each do |story|
            next if story.dig(:story_cta_url).nil?
            story_hash = {
              id: story[:id],
              image: story[:display_url],
              url: story[:story_cta_url]
            }
            if is_new_story?(story_hash)
              key = redis_key(story_hash[:id])
              message = "<strong>ATMOS INSTAGRAM STORY ANNOUNCEMENT DETECTED!</strong>\n"\
                "<a href='#{story_hash[:url]}'>CHECK IT OUT!</a>"
              TelegramBot.new.send_telegram_photo(message, story_hash[:image])
              SneakerWatcherBot.redis.set(key, story_hash.to_json)
              SneakerWatcherBot.redis.expireat(key, redis_expiry.to_i)
            end
          end
        end

        def is_new_story?(story_hash)
          latest_instagram_story_cache = SneakerWatcherBot.redis.get(redis_key(story_hash[:id]))
          return true if latest_instagram_story_cache.blank?
          previous_hash = JSON.parse(latest_instagram_story_cache).deep_symbolize_keys
          previous_hash.except(:image) != story_hash.except(:image)
        end

        private

        def redis_key(identifier)
          "atmos_instagram_story_cta_#{identifier}"
        end

        def instagram_username
          ENV['ATMOS_INSTAGRAM_USERNAME']
        end

        def redis_expiry
          Time.now + 24.hours
        end
      end
    end
  end
end