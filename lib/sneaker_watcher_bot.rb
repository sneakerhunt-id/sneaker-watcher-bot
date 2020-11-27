require 'dotenv'
require 'rest-client'
require 'nokogiri'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/class/subclasses'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/digest/uuid'
require 'json'
require 'telegram/bot'
require 'require_all'

Dotenv.load

require_all 'config/**/*.rb'
require_all 'lib/sneaker_watcher_bot/utilities/**/*.rb'
require_all 'lib/**/base.rb'
require_all 'lib/**/*.rb'

