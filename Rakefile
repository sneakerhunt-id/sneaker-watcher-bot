#!/usr/bin/env rake
# frozen_string_literal: true

require './lib/sneaker_watcher_bot'

namespace :sneaker_watcher_bot do
  desc 'task to execute all scrapers to detect change'
  task :scrapers_detect_change do
    watir_classes =[]
    Service::Scraper::Base.descendants.each do |scraper_class|
      # watir classes process cannot be forked and need to
      # be separated into another single fork
      # is this a bug (?)
      # https://groups.google.com/u/1/g/selenium-users/c/aMmNM7FamWg/m/oMqen9iDAAAJ
      if scraper_class.name.downcase =~ /instagram/
        watir_classes << scraper_class
        next
      end

      # using fork process for better concurrencies
      fork do
        scraper_class.call
      end
    end

    fork do
      watir_classes.each do |watir_class|
        watir_class.call
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
