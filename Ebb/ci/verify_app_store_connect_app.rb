#!/usr/bin/env ruby
# frozen_string_literal: true

require "spaceship"

BUNDLE_ID = "com.brunabaudel.Ebb"

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

apps = Spaceship::ConnectAPI::App.all(filter: { bundleId: BUNDLE_ID })
if apps.any?
  puts "App Store Connect app found for #{BUNDLE_ID}"
  exit 0
end

warn <<~MSG

  No App Store Connect app found for #{BUNDLE_ID}.

  Apple does not allow creating apps via the API — even with an Admin API key.
  Create the app once in your browser:

    https://appstoreconnect.apple.com/apps

  Click + → New App → iOS → Ebb → bundle ID #{BUNDLE_ID} → SKU ebb001

  Then re-run the TestFlight workflow.

MSG

exit 1
