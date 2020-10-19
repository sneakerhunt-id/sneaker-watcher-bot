require 'dotenv'
require 'rest-client'
require 'nokogiri'
require 'active_support/core_ext/hash/keys.rb'
require 'active_support/core_ext/object/blank'
require 'json'
require 'telegram/bot'

Dotenv.load

require_all 'config/**/*.rb'
require_all 'lib/sneaker_watcher_bot/utilities/**/*.rb'
require_all 'lib/**/base.rb'
require_all 'lib/**/*.rb'

