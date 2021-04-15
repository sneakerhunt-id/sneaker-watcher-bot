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

        response = RestClient.post("#{base_url}/accounts/login/", request_body, request_headers)
        cookie_hash = response.cookies.deep_symbolize_keys
        SneakerWatcherBot.redis.set(key, cookie_hash.to_json)
        SneakerWatcherBot.redis.expireat(key, redis_expiry.to_i)
        cookie_hash
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
      Time.now + (ENV['NATIVE_INSTAGRAM_CACHE_EXPIRY'] || 2160).to_i.hours
    end
  
    def base_url
      'https://i.instagram.com/api/v1'
    end
  
    def request_headers
      {
        cookies: cookies,
        user_agent: Helper::CommonHelper::USER_AGENT,
        'X-IG-App-Locale': 'en_US',
        'X-IG-Device-Locale': 'en_US',
        'X-IG-Mapped-Locale': 'en_US',
        'X-IG-Device-ID': @public_key_response.device_id,
        'X-IG-Android-ID': @public_key_response.android_id,
        'X-IG-App-ID': '567067343352427',
        'X-MID': @csrf_token_response.mid,
        'X-FB-HTTP-Engine': 'Liger',
        'X-FB-Client-IP': 'True',
        content_type: :json,
        accept: :json
      }
    end

    def request_body
      signed_body = {
        jazoest: jazoest,
        country_codes: [{
          country_code: '1',
          source: %w[default]
        }].to_json,
        phone_id: @public_key_response.phone_id,
        enc_password: enc_password,
        _csrftoken: @csrf_token_response.csrf_token,
        username: @username,
        adid: '',
        guid: @public_key_response.device_id,
        device_id: @public_key_response.android_id,
        google_tokens: [],
        login_attempt_count: 0
      }
      # {:jazoest=>"22494", :country_codes=>"[{\"country_code\":\"1\",\"source\":[\"default\"]}]", :phone_id=>"e5234c43-f519-4748-9193-ffde9bbeee5e", :enc_password=>"#PWD_INSTAGRAM:4:1606487597:AQa0vSKwTB4LexKIuxUAAaJ5wJQ7yIFRzBUYcWmt11S0Ty6WP4MBi3ke1wUxvAR/rLzvu5EMXAOyq++ITJRmfuvpkXsk2pomtHHKNucoZJ9lZ1QeFvW3OexGLFB+MZI9KZOt3pOwsRxjhT0eOFbJDe31QJsakDbo2wa/EbJ0HkTMMaroVVL0GCzzXlWpGCsDO7vJkOV/KwZZ1wgS1R1UAqBngqWrxkYfy6ujfPv1LfkFesreWSq3KKZ1OhFI8/kVZeQnKKYdE9mn/jJyOdmG3uLQ38ydVoDpY8S42PwVwFn8BSMKKY9eqEcxsCuInT5O10H0/q+9uiCkSkh11yQ39Dj1B3QZ//MItUPLfT2iNVzn9vMicoHGfhZtw1HkgCU7WTmam+FzAHBqmaIa",
      #  :_csrftoken=>"QW0YjrmHXnYuhSfteE6VDfc1UUCmc47u", :username=>"just.a.watcher.69", :adid=>"", :guid=>"18abcabb-8663-4774-85bf-3dddd6d2bd8a", :device_id=>"android-b12551c0f35ad072", :google_tokens=>"[]", :login_attempt_count=>"0"}
      {
        signed_body: "SIGNATURE.#{signed_body.to_json}"
      }
    end

    def cookies
      {
        mid: @csrf_token_response.mid,
        csrftoken: @csrf_token_response.csrf_token
      }
    end

    private

    def enc_password
      time = Time.now.to_i.to_s
      random_key = SecureRandom.bytes(32)
      iv = SecureRandom.bytes(12)

      decoded_public_key = Base64.decode64(@public_key_response.public_key)
      cipher_rsa = OpenSSL::PKey::RSA.new(decoded_public_key)
      enc_random_key = cipher_rsa.public_encrypt(random_key)

      cipher_aes = OpenSSL::Cipher.new('AES-256-GCM')
      cipher_aes.encrypt
      cipher_aes.key = random_key
      cipher_aes.iv = iv
      cipher_aes.auth_data = time.encode('utf-8')
      cipher_text = cipher_aes.update(@password.encode('utf-8')) + cipher_aes.final
      tag = cipher_aes.auth_tag

      # total bytes should be 300
      password_bytes = [1, @public_key_response.public_key_id.to_i].pack('c*') + # 2
        iv + # 12
        [enc_random_key.length].pack("s<") + # 2
        enc_random_key + # 256
        tag + # 16
        cipher_text # 12

      "#PWD_INSTAGRAM:4:#{time}:#{Base64.strict_encode64(password_bytes)}"
    end

    def jazoest
      '2' + @public_key_response.phone_id.bytes.sum.to_s
    end
  end
end