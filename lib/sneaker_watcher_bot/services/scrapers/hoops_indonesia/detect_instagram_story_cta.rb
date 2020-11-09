module Service
  module Scraper
    module HoopsIndonesia
      class DetectInstagramStoryCta < Base
        def self.interval_seconds
          15
        end

        def perform
          stories = InstagramScraper.new.get_stories(instagram_username)
          stories.each do |story|
            next if story.dig(:story_cta_url).nil? || is_base_domain?(story[:story_cta_url])
            story_hash = {
              id: story[:id],
              image: story[:display_url],
              url: story[:story_cta_url]
            }
            if is_new_story?(story_hash)
              key = redis_key(story_hash[:id])
              message = "<strong>HOOPS INDONESIA INSTAGRAM STORY ANNOUNCEMENT DETECTED!</strong>\n"\
                "<a href='#{story_hash[:url]}'>CHECK IT OUT!</a>"
              message += append_additional_info(story_hash[:url]).to_s
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

        def append_additional_info(url)
          additional_message = ""
          return additional_message unless url =~ /\/store\/product/
          begin
            url = url.sub('store','api').sub('product', 'products')
            response = RestClient.get(url)
            if response.code == 200 && !response.body.blank? && response.body != 'null'
              raw_product_data = JSON.parse(response.body).deep_symbolize_keys
              product_name = raw_product_data.dig(:Products, :Name)
              additional_message += "\n#{product_name}" if product_name.present?
              sizes = raw_product_data[:Options].select do |o| 
                o[:Title].downcase.gsub(/[^0-9a-z ]/i, '') == 'size'
              end.first[:Options]
              return additional_message if sizes.blank?
              additional_message += "\n\nAVAILABLE SIZE:"
              sizes.each do |size|
                next if size[:Quantity] == 0
                additional_message += "\n#{size[:Value]} - #{size[:Quantity].to_i} PCS"
              end
            end
          rescue
            # do nothing because it is not mandatory
          end
          additional_message
        end

        def redis_key(identifier)
          "hoops_indonesia_instagram_story_cta_#{identifier}"
        end

        def instagram_username
          ENV['HOOPS_INDONESIA_INSTAGRAM_USERNAME']
        end

        def redis_expiry
          Time.now + 24.hours
        end
      end
    end
  end
end