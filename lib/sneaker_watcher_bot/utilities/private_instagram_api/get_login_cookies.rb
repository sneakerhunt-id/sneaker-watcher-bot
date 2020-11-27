require 'watir'
require 'webdrivers/chromedriver'

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
        @csrf_token_response = GetCsrfToken.new(@username, @password).perform
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
  
    def get_cookies
      key = redis_instagram_cookies_key(@username)
      raw_cookies = SneakerWatcherBot.redis.get(key)
      return JSON.parse(raw_cookies).deep_symbolize_keys if raw_cookies.present?
      # cookies expired
      # do relogin to get latest cookies
      relogin
      cookie_hash = parse_cookies_from_watir_browser
      SneakerWatcherBot.redis.set(key, cookie_hash.to_json)
      SneakerWatcherBot.redis.expireat(key, redis_expiry.to_i)
      cookie_hash
    end
  
    def reel_id(target_username, cookies)
      key = redis_instagram_reel_id(target_username)
      reel_id = SneakerWatcherBot.redis.get(key)
      return reel_id if reel_id.present?
      url = "#{INSTAGRAM_BASE_URL}/#{target_username}/?__a=1"
      response = RestClient.get(url, cookies: cookies)
      profile = JSON.parse(response.body).deep_symbolize_keys
      reel_id = profile[:logging_page_id].split('_')[1]
      SneakerWatcherBot.redis.set(key, reel_id)
      SneakerWatcherBot.redis.expireat(key, redis_expiry.to_i)
      reel_id
    end
  
    def set_instagram_account
      # randomize from a pool of instagram accounts
      account = ENV['INSTAGRAM_ACCOUNTS'].split(',').map(&:strip).compact.sample
      @username, @password = account.split(':')
      log_object = {
        tags: self.class.name.underscore,
        message: "Set instagram scraper account",
        instagram_username: @username
      }
      SneakerWatcherBot.logger.info(log_object)
    end
  
    def relogin
      # do re-login to get cookies
      return if @logged_in
      
      @browser.goto 
      @browser.text_field(id: 'id_username').set @username
      @browser.text_field(id: 'id_enc_password').set @password
      @browser.button(type: 'submit').click
      # indicator that we're logged in
      Watir::Wait.until { @browser.title.strip.upcase == 'INSTAGRAM' }
      @logged_in = true
    end
  
    def parse_cookies_from_watir_browser
      latest_cookies = @browser.cookies.to_a
      latest_cookies.each_with_object({}) do |cookie, cookie_hash|
        cookie_hash[cookie[:name].to_sym] = cookie[:value]
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
        'X-MID': @csrf_token_response.mid
        'X-FB-HTTP-Engine': 'Liger',
        'X-FB-Client-IP': 'True',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    end

    def request_body
      {
        
      }
    end

    def cookies
      {
        mid: @csrf_token_response.mid,
        csrftoken: @csrf_token_response.csrf_token
      }
    end
  end
end
