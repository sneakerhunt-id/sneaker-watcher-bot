require 'watir'
require 'webdrivers/chromedriver'

class InstagramScraper
  INSTAGRAM_BASE_URL = 'https://www.instagram.com'

  def initialize
    set_instagram_account
    Selenium::WebDriver::Chrome.path = ENV['GOOGLE_CHROME_SHIM'] if ENV.fetch('GOOGLE_CHROME_SHIM', nil).present?
    @browser = Watir::Browser.new :chrome, args: %w[--headless --no-sandbox --disable-dev-shm-usage --disable-gpu --remote-debugging-port=9222]
  end

  def get_stories(target_username)
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
    @browser.close
    stories
  end

  private

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
  end

  def relogin
    # do re-login to get cookies
    return if @logged_in
    @browser.goto "#{INSTAGRAM_BASE_URL}/accounts/login/?force_classic_login"
    @browser.text_field(id: 'id_username').set @username
    @browser.text_field(id: 'id_enc_password').set @password
    @browser.button(type: 'submit').click
    Watir::Wait.until { @browser.text.include? 'INSTAGRAM FROM FACEBOOK' }
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
end
