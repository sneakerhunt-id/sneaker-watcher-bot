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
    # login
    @browser.goto "#{INSTAGRAM_BASE_URL}/accounts/login/?force_classic_login"
    @browser.text_field(id: 'id_username').set @username
    @browser.text_field(id: 'id_enc_password').set @password
    @browser.button(type: 'submit').click
    
    # get stories data
    Watir::Wait.until { @browser.text.include? 'INSTAGRAM FROM FACEBOOK' }
    @browser.goto "#{INSTAGRAM_BASE_URL}/#{target_username}/?__a=1"
    Watir::Wait.until { @browser.text.include? 'logging_page_id' }
    profile = JSON.parse(@browser.text).deep_symbolize_keys
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
    Watir::Wait.until { @browser.text.include? 'reels_media' }
    raw_stories_data = JSON.parse(@browser.text).deep_symbolize_keys
    stories = raw_stories_data.dig(:data, :reels_media)&.first&.dig(:items) || []
    @browser.close
    stories
  end
end
