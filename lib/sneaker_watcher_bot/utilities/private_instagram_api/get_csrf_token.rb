module PrivateInstagramApi
  class GetCsrfToken
    def initialize(username, password, device_id, android_id)
      @username = username
      @password = password
      @device_id = device_id
      @android_id = android_id
    end
  
    def perform
      begin
        response = RestClient.get("#{base_url}/zr/token/result/", request_headers)
        cookies = response.cookies.deep_symbolize_keys
        Normalizer::CsrfTokenResponse.new(cookies[:csrftoken], cookies[:mid])
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

    def base_url
      'https://b.i.instagram.com/api/v1'
    end

    def request_headers
      {
        params: query_string,
        user_agent: Helper::CommonHelper::USER_AGENT,
        'X-IG-App-Locale': 'en_US',
        'X-IG-Device-Locale': 'en_US',
        'X-IG-Mapped-Locale': 'en_US',
        'X-IG-Device-ID': @device_id,
        'X-IG-Android-ID': @android_id,
        'X-IG-App-ID': '567067343352427',
        'X-FB-HTTP-Engine': 'Liger',
        'X-FB-Client-IP': 'True'
      }
    end

    def query_string
      {
        device_id: @android_id,
        token_hash: '',
        custom_device_id: @device_id,
        fetch_reason: 'token_expired'
      }
    end
  end
end
