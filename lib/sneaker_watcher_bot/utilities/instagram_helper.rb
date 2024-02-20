require 'pry'

module InstagramHelper
  INSTAGRAM_BASE_URL = 'https://www.instagram.com'

  def scrape_stories(target_username, username, password)
    begin
      cookies = get_cookies(username, password)
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
        instagram_username: username
      }
      SneakerWatcherBot.logger.error(log_object)
      send_error_notification(e, username, password)
      raise
    end
  end

  def scrape_feeds(target_username, username, password, limit = 3)
    begin
      cookies = get_cookies(username, password)
      url = "#{INSTAGRAM_BASE_URL}/#{target_username}/?__a=1"
      response = RestClient.get(url, cookies: cookies)
      raw_data = JSON.parse(response.body).deep_symbolize_keys
      feeds = raw_data.dig(:graphql, :user, :edge_owner_to_timeline_media, :edges)
      feeds.take(limit).map do |feed|
        {
          id: feed.dig(:node, :id),
          short_code: feed.dig(:node, :shortcode),
          url: "#{INSTAGRAM_BASE_URL}/p/#{feed.dig(:node, :shortcode)}",
          image: feed.dig(:node, :display_url),
          text: feed.dig(:node, :edge_media_to_caption, :edges)&.first&.dig(:node, :text)
        }
      end
    rescue StandardError => e
      log_object = {
        tags: self.class.name.underscore,
        message: e.message,
        backtrace: e.backtrace.take(5),
        instagram_username: username
      }
      SneakerWatcherBot.logger.error(log_object)
      send_error_notification(e, username, password)
      raise
    end
  end

  private

  def get_cookies(username, password)
    PrivateInstagramApi::GetLoginCookies.new(username, password).perform
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
    username, password = account.split(':')
    log_object = {
      tags: self.class.name.underscore,
      message: "Set instagram scraper account",
      instagram_username: @username
    }
    SneakerWatcherBot.logger.info(log_object)
    return [username, password]
  end

  def send_error_notification(error, username, password)
    message = "#{username}:#{password} instagram scraping error\n"\
      "Error message: #{error.message}"
    TelegramBot.new(ENV['TELEGRAM_PRODUCTION_SUPPORT_CHAT_ID']).send_telegram_message(message)
  end

  def redis_instagram_reel_id(target_username)
    "instagram_reel_id_#{target_username}"
  end

  def redis_expiry
    Time.now + (ENV['INSTAGRAM_CACHE_EXPIRY'] || 12).to_i.hours
  end
end
