class TelegramBot
  def initialize(chat_id = ENV['TELEGRAM_CHAT_ID'], token = ENV['TELEGRAM_BOT_TOKEN'])
    @chat_id = chat_id
    @token = token
  end

  def send_telegram_message(text, parse_mode = 'HTML')
    Telegram::Bot::Client.run(@token) do |bot|
      bot.api.send_message(
        chat_id: @chat_id,
        text: text,
        parse_mode: parse_mode, # choice is 'HTML' / 'markdown'
        disable_web_page_preview: true
      )
    end
  end
  
  def send_telegram_photo(text, image_url, parse_mode = 'HTML')
    Telegram::Bot::Client.run(@token) do |bot|
      bot.api.send_photo(
        chat_id: @chat_id,
        photo: image_url,
        caption: text,
        parse_mode: parse_mode # choice is 'HTML' / 'markdown'
      )
    end
  end
end