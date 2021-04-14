module Service
  module Scraper
    class Base < Services::Base
      private

      def is_base_domain?(url)
        url.split('/').last == URI.parse(url).host
      end

      def raffle?(product_url)
        is_raffle = product_url.downcase =~ /raffle/
        is_raffle.present?
      end

      def whitelisted_products
        raise NotImplementedError, 'You must implement `whitelisted_products`.'
      end

      def relevant_product?(product)
        return true if whitelisted_products.blank? # it means no preferences
        relevancy = product.downcase =~ /#{whitelisted_products.join('|')}/
        relevancy.present?
      end
    end
  end
end
