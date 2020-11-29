module PrivateInstagramApi
  class GetLoginCookies
    def initialize(username, password)
      @username = username
      @password = password
    end
  
    def perform
      begin
        key = redis_instagram_cookies_key(@username)
        raw_cookies = SneakerWatcherBot.redis.get(key)
        return JSON.parse(raw_cookies).deep_symbolize_keys if raw_cookies.present?
        @public_key_response = GetPublicKey.new(@username, @password).perform
        @csrf_token_response = GetCsrfToken.new(
          @username,
          @password,
          @public_key_response.device_id,
          @public_key_response.android_id
        ).perform
        SneakerWatcherBot.redis.set(key, cookie_hash.to_json)
        SneakerWatcherBot.redis.expireat(key, redis_expiry.to_i)
        response.cookies
      rescue => e
        log_object = {
          tags: self.class.name.underscore,
          message: e.message,
          backtrace: e.backtrace.take(5),
          instagram_username: @username
        }
        SneakerWatcherBot.logger.error(log_object)
        raise
      end
    end
  
    def redis_instagram_cookies_key(username)
      "native_instagram_cookies_#{username}"
    end
  
    def redis_expiry
      Time.now + (ENV['INSTAGRAM_CACHE_EXPIRY'] || 12).to_i.hours
    end
  
    def base_url
      'https://i.instagram.com/api/v1'
    end
  
    def request_headers
      {
        cookies: cookies,
        user_agent: 'Instagram 165.1.0.29.119 Android (26/8.0.0; 320dpi; 720x1468; samsung; SM-A102U; a10e; exynos7885; en_US; 239490550)',
        'X-IG-App-Locale': 'en_US',
        'X-IG-Device-Locale': 'en_US',
        'X-IG-Mapped-Locale': 'en_US',
        'X-IG-Device-ID': @csrf_token_response.device_id,
        'X-IG-Android-ID': @csrf_token_response.android_id,
        'X-IG-App-ID': '567067343352427',
        'X-MID': @csrf_token_response.mid,
        'X-FB-HTTP-Engine': 'Liger',
        'X-FB-Client-IP': 'True',
        content_type: :json,
        accept: :json
      }
    end

    def request_body
      {
        # signed_bodySIGNATURE.%7B%22jazoest%22%3A%2222326%22%2C%22country_codes%22%3A%22%5B%7B%5C%22country_code%5C%22%3A%5C%221%5C%22%2C%5C%22source%5C%22%3A%5B%5C%22default%5C%22%5D%7D%5D%22%2C%22phone_id%22%3A%225a8198e4-aef7-4204-9121-2d8abc9861a2%22%2C%22enc_password%22%3A%22%23PWD_INSTAGRAM%3A4%3A1606412328%3AAbr37cSm%2Bn4s1cLMdbgAATKznHkIMRhJ2a3rVaPt5lIOCGQSFpfiNuFQ8vgNPWjgb20SXhp1P6i%2BVv55LyUFxD3UW9XFOJapy7z5Pb%2F%2BbnAPC9847Yf46WeGIjWS7U20BQDWtUt%2Bxb34XK0JKU8eEpBHacBcg0rmCGfHTVqZDQJc%2FAO3O5iySGMBikQSUYMY1PjwkoVI1S4kkyMoC2ACEQsD2ElzF43%2BMMCw9cOzszRwXsQcG3ltxt1%2FpF3nIbmai96FDjbrLvRCrUrmKH9TPfqMvsVhAfE6BIIRAVKXQ5abA%2FrNEDUxBLuq6Oq%2BKKJnUb6Q5Bxcpda8Bm4b6sZTryPVMUr%2FRTsga%2BpUc%2FHTGlOj1%2FgARLuYIW8kz6zi%2FK%2BGWOynDdiX77%2BPT0Ef%22%2C%22_csrftoken%22%3A%22ZKroefVz4stGdTgm2ORoS9TsFXD4dDXi%22%2C%22username%22%3A%22just.a.watcher.69%22%2C%22adid%22%3A%22%22%2C%22guid%22%3A%22dcd5c6f0-e663-412d-b69c-5d95ad76f0c1%22%2C%22device_id%22%3A%22android-b12551c0f35ad072%22%2C%22google_tokens%22%3A%22%5B%5D%22%2C%22login_attempt_count%22%3A%221%22%7D
      }
    end

    def cookies
      {
        mid: @csrf_token_response.mid,
        csrftoken: @csrf_token_response.csrf_token
      }
    end

    private

    def get_enc_password
      decoded_public_key = Base64.decode64(@public_key_response.public_key)
      cipher_aes = OpenSSL::Cipher.new('AES-256-GCM')
      cipher_aes.encrypt
      random_key = cipher_aes.random_key
      iv = cipher_aes.random_iv
      time = Time.now.to_i.to_s
      cipher_rsa = OpenSSL::PKey::RSA.new(decoded_public_key)
      enc_random_key = cipher_rsa.public_encrypt(random_key)
      chipered_password = cipher_aes.update(@password.encode('utf-8')) + cipher.final
      # cipher_aes.update(time.encode)
      "#PWD_INSTAGRAM:4:#{time}:#{payload}"
    end
  end
end
