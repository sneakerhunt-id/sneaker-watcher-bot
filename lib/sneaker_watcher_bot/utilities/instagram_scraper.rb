require 'watir'
require 'webdrivers/chromedriver'

class InstagramScraper
  INSTAGRAM_BASE_URL = 'https://www.instagram.com'

  def initialize
    @username = ENV['INSTAGRAM_USERNAME']
    @password = ENV['INSTAGRAM_PASSWORD']
    Selenium::WebDriver::Chrome.path = ENV['GOOGLE_CHROME_SHIM'] if ENV.fetch('GOOGLE_CHROME_SHIM', nil).present?
    @browser = Watir::Browser.new :chrome, args: %w[--headless --no-sandbox --disable-dev-shm-usage --disable-gpu --remote-debugging-port=9222]
  end

  def get_stories(target_username)
    @cookies ||= begin
      # login
      @browser.goto "#{INSTAGRAM_BASE_URL}/accounts/login/?force_classic_login"
      @browser.text_field(id: 'id_username').set @username
      @browser.text_field(id: 'id_enc_password').set @password
      @browser.button(type: 'submit').click
      
      # get stories data
      @browser.goto "#{INSTAGRAM_BASE_URL}/#{target_username}/?__a=1"
      profile = JSON.parse(@browser.text).symbolize_keys
      reel_id = profile[:logging_page_id].split('_')[1]
      variables = {
        reel_ids: [reel_id],
        tag_names: [],
        location_ids: [],
        highlight_reel_ids: [],
        precomposed_overlay: false,
        show_story_viewer_list: true,
        story_viewer_fetch_count: 50,
        stories_video_dash_manifest: false
      }
      @browser.goto "#{INSTAGRAM_BASE_URL}/graphql/query/?query_hash=c9c56db64beb4c9dea2d17740d0259d9&variables=#{variables.to_json}"
      raw_stories_data = JSON.parse(@browser.text).deep_symbolize_keys
      raw_stories_data.dig(:data, :reels_media)&.first&.dig(:items) || []
    end
  end
  
  def send_telegram_photo(text, image_url)
    Telegram::Bot::Client.run(@token) do |bot|
      bot.api.send_photo(
        chat_id: @chat_id,
        photo: image_url,
        caption: text,
        parse_mode: "markdown"
      )
    end
  end
end