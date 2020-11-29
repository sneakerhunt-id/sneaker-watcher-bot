module PrivateInstagramApi
  module Normalizer
    class PublicKeyResponse
      attr_reader :public_key_id, :public_key, :device_id, :android_id
      def initialize(public_key_id, public_key, device_id, android_id)
        @public_key_id = public_key_id
        @public_key = public_key
        @device_id = device_id
        @android_id = android_id
      end
    end
  end
  
end
