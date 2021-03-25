module Service
  module Scraper
    module Atmos
      class DetectCollectionsChange < Base
        include ::ShopifyHelper

        def self.interval_seconds
          (ENV['ATMOS_COLLECTIONS_INTERVAL_SECONDS'] || 3).to_i
        end

        def perform
          collections.each do |collection|
            scrape_collection_products(prefix, base_url, collection, fetch_limit)
          end
        end

        private

        def prefix
          'atmos'
        end

        def collections
          ENV['ATMOS_COLLECTIONS'].split(',').map(&:strip).compact
        end

        def fetch_limit
          (ENV['ATMOS_FETCH_LIMIT'] || 8).to_i
        end

        def base_url
          ENV['ATMOS_BASE_URL']
        end

        def whitelisted_products
          @whitelisted_products ||= ENV['ATMOS_COLLECTIONS_WHITELISTED_PRODUCTS'].split(",")
            .map(&:strip).map(&:downcase).compact
        end

        def redis_expiry
          Time.now + 24.hours
        end
      end
    end
  end
end
