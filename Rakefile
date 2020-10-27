#!/usr/bin/env rake
# frozen_string_literal: true

require './lib/sneaker_watcher_bot'

namespace :sneaker_watcher_bot do
  desc 'task to execute all scrapers to detect change'
  task :scrapers_detect_change do
    # fork process for better concurrencies
    children = []

    Service::Scraper::Base.descendants.each do |scraper_class|
      children << fork do
        scraper_class.call
      end
    end

    # wait for all processes to be done
    # before exiting
    Process.waitall
  end

  desc 'task to keep heroku service awake'
  task :keep_heroku_awake do
    begin
      response = RestClient.get("#{ENV['HEROKU_SERVICE_URL']}")
    rescue RestClient::Exception => e
      error = e
    end
  end
end
