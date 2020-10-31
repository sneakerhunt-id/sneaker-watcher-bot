module Service
  module Scraper
    class Base < Services::Base
      private

      def is_base_domain?(url)
        url.split('/').last == URI.parse(url).host
      end
    end
  end
end
