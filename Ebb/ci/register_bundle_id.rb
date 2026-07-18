#!/usr/bin/env ruby
# frozen_string_literal: true

require "spaceship"

require_relative "bundle_capabilities"

BUNDLE_ID = EbbBundleCapabilities::BUNDLE_ID
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
  EbbBundleCapabilities.ensure_all!(existing)
  puts "Bundle ID already registered: #{BUNDLE_ID}"
  exit 0
end

bundle = Spaceship::ConnectAPI::BundleId.create(
  name: BUNDLE_NAME,
  identifier: BUNDLE_ID,
  platform: Spaceship::ConnectAPI::Platform::IOS
)

EbbBundleCapabilities.ensure_all!(bundle)

puts "Registered bundle ID: #{BUNDLE_ID}"
