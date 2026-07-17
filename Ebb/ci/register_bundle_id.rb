#!/usr/bin/env ruby
# frozen_string_literal: true

require "spaceship"

BUNDLE_ID = "com.bcbs.ebb"
BUNDLE_NAME = "Ebb"

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

existing = Spaceship::ConnectAPI::BundleId.find(BUNDLE_ID)
if existing
  unless existing.get_capabilities.any? do |cap|
           cap.is_type?(Spaceship::ConnectAPI::BundleIdCapability::Type::HEALTHKIT)
         end
    existing.create_capability(Spaceship::ConnectAPI::BundleIdCapability::Type::HEALTHKIT)
    puts "Enabled HealthKit capability on #{BUNDLE_ID}"
  end
  puts "Bundle ID already registered: #{BUNDLE_ID}"
  exit 0
end

bundle = Spaceship::ConnectAPI::BundleId.create(
  name: BUNDLE_NAME,
  identifier: BUNDLE_ID,
  platform: Spaceship::ConnectAPI::Platform::IOS
)

bundle.create_capability(Spaceship::ConnectAPI::BundleIdCapability::Type::HEALTHKIT)

puts "Registered bundle ID: #{BUNDLE_ID}"
