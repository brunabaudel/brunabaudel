#!/usr/bin/env ruby
# frozen_string_literal: true

require "spaceship"

BUNDLE_ID = "com.bcbs.ebb"
GROUP_NAME = "Ebb Testers"

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

app = Spaceship::ConnectAPI::App.find(BUNDLE_ID)
abort("No App Store Connect app found for #{BUNDLE_ID}") unless app

group = app.get_beta_groups.find { |g| g.name == GROUP_NAME }

if group
  puts "Beta group already exists: #{GROUP_NAME}"
else
  group = app.create_beta_group(
    group_name: GROUP_NAME,
    is_internal_group: false,
    public_link_enabled: true,
    public_link_limit: 100,
    public_link_limit_enabled: true
  )
  puts "Created beta group: #{GROUP_NAME}"
end

unless group.public_link_enabled
  group.update(attributes: {
    public_link_enabled: true,
    public_link_limit: 100,
    public_link_limit_enabled: true
  })
  group = app.get_beta_groups.find { |g| g.name == GROUP_NAME }
  puts "Enabled public link for: #{GROUP_NAME}"
end

if group.public_link
  puts "Public invite link: #{group.public_link}"
else
  puts "Public link not available yet (it appears once the group has a build)"
end
