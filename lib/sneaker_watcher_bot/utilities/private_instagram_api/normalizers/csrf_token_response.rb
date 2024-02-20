module PrivateInstagramApi
  module Normalizer
    class CsrfTokenResponse
      attr_reader :csrf_token, :mid
      def initialize(csrf_token, mid)
        @csrf_token = csrf_token
        @mid = mid
      end
    end
  end
  
end
