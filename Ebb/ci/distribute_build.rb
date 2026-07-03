#!/usr/bin/env ruby
# frozen_string_literal: true

# Assigns an uploaded build to the external beta group and submits it for
# Beta App Review (required by Apple before external testers can install it).
# Waits for App Store Connect to finish processing the build first.

require "spaceship"

BUNDLE_ID = "com.bcbs.ebb"
GROUP_NAME = "Ebb Testers"
POLL_INTERVAL = 30 # seconds
TIMEOUT = 45 * 60 # seconds

build_number = ENV.fetch("BUILD_NUMBER")
key_id = ENV.fetch("APPSTORE_API_KEY_ID")
issuer_id = ENV.fetch("APPSTORE_ISSUER_ID")
key_path = File.expand_path(
  "~/.appstoreconnect/private_keys/AuthKey_#{key_id}.p8"
)

abort("API key file not found: #{key_path}") unless File.exist?(key_path)

token = Spaceship::ConnectAPI::Token.create(
  key_id: key_id,
  issuer_id: issuer_id,
  filepath: key_path
)
Spaceship::ConnectAPI.token = token

app = Spaceship::ConnectAPI::App.find(BUNDLE_ID)
abort("No App Store Connect app found for #{BUNDLE_ID}") unless app

group = app.get_beta_groups.find { |g| g.name == GROUP_NAME }
abort("Beta group not found: #{GROUP_NAME} (run create_beta_group.rb first)") unless group

puts "Waiting for build #{build_number} to finish processing..."
deadline = Time.now + TIMEOUT
build = nil

loop do
  token.refresh! if token.expired?
  build = Spaceship::ConnectAPI::Build.all(
    app_id: app.id,
    build_number: build_number
  ).first

  if build&.processed? && build.build_beta_detail&.processed?
    puts "Build processed: #{build.app_version} (#{build.version})"
    break
  end

  if Time.now > deadline
    abort(
      "Timed out waiting for build #{build_number} to process. " \
      "Re-run this workflow once the build shows up in TestFlight."
    )
  end

  state = build ? build.processing_state : "NOT_VISIBLE_YET"
  puts "  still processing (#{state}), retrying in #{POLL_INTERVAL}s..."
  sleep(POLL_INTERVAL)
end

if build.build_beta_detail.missing_export_compliance?
  abort(
    "Build is missing export compliance. " \
    "ITSAppUsesNonExemptEncryption should be set in the Xcode project."
  )
end

if build.ready_for_beta_submission?
  build.post_beta_app_review_submission
  puts "Submitted build for Beta App Review"
else
  puts "Beta App Review submission not needed " \
       "(state: #{build.build_beta_detail.external_build_state})"
end

already_assigned = group.fetch_builds.any? { |b| b.id == build.id }
if already_assigned
  puts "Build already assigned to group: #{GROUP_NAME}"
else
  build.add_beta_groups(beta_groups: [group])
  puts "Assigned build #{build_number} to group: #{GROUP_NAME}"
end

group = app.get_beta_groups.find { |g| g.name == GROUP_NAME }
puts "Public invite link: #{group.public_link}" if group.public_link
