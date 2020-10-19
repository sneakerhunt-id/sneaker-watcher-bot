require './dependencies'
require 'pry'
require 'telegram/bot'

@atmos_base_url = ENV['ATMOS_BASE_URL']
@token = ENV['TELEGRAM_BOT_TOKEN']
@chat_id = ENV['TELEGRAM_CHAT_ID']

def scrape_info
  response = RestClient.get("#{@atmos_base_url}/collections/new-arrivals")
  html = Nokogiri::HTML(response.body)
  latest_product_grid = html.css('.product.grid-item').first
  latest_product_url = latest_product_grid.elements.first.attributes['href'].value
  latest_product_name = latest_product_grid.css('.product-title').first.inner_text
  latest_product_img = latest_product_grid.xpath("//*[@id='panel']/section/div[2]/div[2]/div/div[1]/article/a/div[1]/img").first.attributes['src'].value
  latest_product_img = "https:#{latest_product_img}"
  {
    name: latest_product_name,
    url: latest_product_url,
    image: latest_product_img
  }
end

def detect_change
  new_hash = scrape_info
  if is_new_product?(new_hash)
    AtmosIdBot.redis.set('atmos_latest_product_new_arrival', new_hash.to_json)
    message = "*ATMOS NEW ARRIVAL UPDATE DETECTED!*\n"\
      "[#{new_hash[:name]}](#{@atmos_base_url}#{new_hash[:url]})"
    send_telegram_photo(message, new_hash[:image])
  end
end

def is_new_product?(new_hash)
  @is_new_product ||= begin
    latest_product_new_arrival_cache = AtmosIdBot.redis.get('atmos_latest_product_new_arrival')
    return true if latest_product_new_arrival_cache.blank?
    previous_hash = JSON.parse(latest_product_new_arrival_cache).symbolize_keys
    previous_hash != new_hash
  end
end

def send_telegram_message(text)
  Telegram::Bot::Client.run(@token) do |bot|
    bot.api.send_message(
      chat_id: @chat_id,
      text: text,
      parse_mode: "markdown",
      disable_web_page_preview: true
    )
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

def clear_cache
  AtmosIdBot.redis.del('atmos_latest_product_new_arrival')
end

detect_change