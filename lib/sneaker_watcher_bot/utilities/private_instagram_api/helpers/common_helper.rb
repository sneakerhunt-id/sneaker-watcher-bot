module PrivateInstagramApi
  module Helper
    class CommonHelper
      def self.get_device_id(username, password)
        # generate uuid based on username password
        Digest::UUID.uuid_v5(username, password)
      end

      def self.generate_android_id
        "android-#{SecureRandom.hex(8)}"
      end
    end
  end
end
