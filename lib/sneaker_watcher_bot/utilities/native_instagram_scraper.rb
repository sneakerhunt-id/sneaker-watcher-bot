require 'watir'
require 'webdrivers/chromedriver'

class NativeInstagramScraper
  def initialize
    set_instagram_account
    Selenium::WebDriver::Chrome.path = ENV['GOOGLE_CHROME_SHIM'] if ENV.fetch('GOOGLE_CHROME_SHIM', nil).present?
    @browser = Watir::Browser.new :chrome, args: %w[--headless --no-sandbox --disable-dev-shm-usage --disable-gpu --remote-debugging-port=9222]
  end

  def get_stories(target_username)
    begin
      cookies = get_cookies
      variables = {
        reel_ids: [reel_id(target_username, cookies)],
        tag_names: [],
        location_ids: [],
        highlight_reel_ids: [],
        precomposed_overlay: false,
        show_story_viewer_list: true,
        story_viewer_fetch_count: 50,
        stories_video_dash_manifest: false
      }
      # get stories data
      url = "#{INSTAGRAM_BASE_URL}/graphql/query/?query_hash=c9c56db64beb4c9dea2d17740d0259d9&variables=#{variables.to_json}"
      response = RestClient.get(url, cookies: cookies)
      raw_stories_data = JSON.parse(response.body).deep_symbolize_keys
      stories = raw_stories_data.dig(:data, :reels_media)&.first&.dig(:items) || []
    rescue StandardError => e
      log_object = {
        tags: self.class.name.underscore,
        message: e.message,
        backtrace: e.backtrace.take(5),
        instagram_username: @username
      }
      SneakerWatcherBot.logger.error(log_object)
      send_error_notification(e)
      raise
    ensure
      @browser.close
    end
  end

  private

  def send_error_notification(error)
    key = "instagram_error_#{@username}"
    cached_error = SneakerWatcherBot.redis.get(key)
    if cached_error.nil?
      error_expiry = Time.now + 30.minutes
      message = "#{@username}:#{@password} instagram scraping error\n"\
        "Error message: #{error.message}"
      TelegramBot.new(ENV['TELEGRAM_PRODUCTION_SUPPORT_CHAT_ID']).send_telegram_message(message)
      SneakerWatcherBot.redis.set(key, message)
      SneakerWatcherBot.redis.expireat(key, error_expiry.to_i)
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
    "instagram_cookies_#{username}"
  end

  def redis_instagram_reel_id(target_username)
    "instagram_reel_id_#{target_username}"
  end

  def redis_expiry
    Time.now + (ENV['INSTAGRAM_CACHE_EXPIRY'] || 12).to_i.hours
  end

  def base_url
    'https://i.instagram.com/api/v1'
  end

  def base_url2
    'https://b.i.instagram.com/api/v1'
  end

  def request_header
    {
      user_agent: 'Instagram 165.1.0.29.119 Android (26/8.0.0; 320dpi; 720x1468; samsung; SM-A102U; a10e; exynos7885; en_US; 239490550)',
      'X-IG-App-Locale': 'en_US',
      'X-IG-Device-Locale': 'en_US',
      'X-IG-Mapped-Locale': 'en_US',
      'X-IG-Device-ID': device_id,
      'X-IG-Android-ID': "android-#{SecureRandom.hex(8)}",
      'X-IG-App-ID': '567067343352427',
      'X-FB-HTTP-Engine': 'Liger',
      'X-FB-Client-IP': 'True'
    }
  end

  def device_id
    Digest::UUID.uuid_v5(@username, @password)
  end
end
