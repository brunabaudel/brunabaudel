#!/usr/bin/env ruby
# frozen_string_literal: true

require "spaceship"

BUNDLE_ID = "com.brunabaudel.BasicApp"
APP_NAME = "BasicApp"
SKU = "basicapp001"

key_id = ENV.fetch("APPSTORE_API_KEY_ID")
issuer_id = ENV.fetch("APPSTORE_ISSUER_ID")
key_path = File.expand_path(
  "~/.appstoreconnect/private_keys/AuthKey_#{key_id}.p8"
)

abort("API key file not found: #{key_path}") unless File.exist?(key_path)

Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
  key_id: key_id,
  issuer_id: issuer_id,
  filepath: key_path
)

apps = Spaceship::ConnectAPI::App.all(bundle_ids: BUNDLE_ID)
if apps.any?
  puts "App Store Connect app already exists for #{BUNDLE_ID}"
  exit 0
end

Spaceship::ConnectAPI::App.create(
  name: APP_NAME,
  bundle_id: BUNDLE_ID,
  sku: SKU,
  primary_locale: "en-US"
)

puts "Created App Store Connect app #{APP_NAME}"
