module Service
  module Scraper
    module InvincibleId
      class DetectCollectionsChange < Base
        include ::ShopifyHelper

        def self.interval_seconds
          (ENV['INVINCIBLE_ID_COLLECTIONS_INTERVAL_SECONDS'] || 5).to_i
        end

        def perform
          collections.each do |collection|
            scrape_collection_products(prefix, base_url, collection, fetch_limit, redis_expiry, :option2)
          end
        end

        private

        def prefix
          'invincible_id'
        end

        def collections
          ENV['INVINCIBLE_ID_COLLECTIONS'].split(',').map(&:strip).compact
        end

        def fetch_limit
          (ENV['INVINCIBLE_ID_FETCH_LIMIT'] || 8).to_i
        end

        def base_url
          ENV['INVINCIBLE_ID_BASE_URL']
        end

        def whitelisted_products
          @whitelisted_products ||= ENV['INVINCIBLE_ID_COLLECTIONS_WHITELISTED_PRODUCTS'].split(",")
            .map(&:strip).map(&:downcase).compact
        end

        def redis_expiry
          Time.now + 24.hours
        end
      end
    end
  end
end
