module PrivateInstagramApi
  module Normalizer
    class CsrfTokenResponse
      attr_reader :csrf_token, :mid, :device_id, :android_id
      def initialize(csrf_token, mid, device_id, android_id)
        @csrf_token = csrf_token
        @mid = mid
        @device_id = device_id
        @android_id = android_id
      end
    end
  end
  
end
