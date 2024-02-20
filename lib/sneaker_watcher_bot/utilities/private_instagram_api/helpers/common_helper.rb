module PrivateInstagramApi
  module Helper
    class CommonHelper
      USER_AGENT = 'Instagram 165.1.0.29.119 Android (26/8.0.0; 320dpi; 720x1468; samsung; SM-A102U; a10e; exynos7885; en_US; 239490550)'

      def self.get_device_id(username, password)
        # generate uuid based on username password
        Digest::UUID.uuid_v5(username, password)
      end

      def self.get_phone_id(device_id)
        # generate uuid based on username password
        Digest::UUID.uuid_v5(Digest::UUID::DNS_NAMESPACE, device_id)
      end

      def self.generate_android_id
        "android-#{SecureRandom.hex(8)}"
      end
    end
  end
end
