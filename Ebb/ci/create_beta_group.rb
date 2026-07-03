#!/usr/bin/env ruby
# frozen_string_literal: true

# Creates the internal TestFlight group (idempotent) and adds the owner as a
# tester. Internal groups skip Beta App Review, and with "access to all
# builds" enabled every uploaded build is distributed automatically once
# Apple finishes processing it — no per-build assignment step needed.
#
# Internal group testers must be members of the App Store Connect team.

require "spaceship"

BUNDLE_ID = "com.bcbs.ebb"
GROUP_NAME = "Ebb Internal"
TESTERS = [
  { email: "brubaudel@gmail.com", firstName: "Bruna", lastName: "Baudel" }
].freeze

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
  # Spaceship's App#create_beta_group always sends publicLink* attributes,
  # which Apple rejects for internal groups ("Public link limit cannot be
  # applied to internal group"). Post the creation request directly instead.
  body = {
    data: {
      type: "betaGroups",
      attributes: {
        name: GROUP_NAME,
        isInternalGroup: true,
        hasAccessToAllBuilds: true
      },
      relationships: {
        app: { data: { type: "apps", id: app.id } }
      }
    }
  }
  resp = Spaceship::ConnectAPI.client
                              .test_flight_request_client
                              .post("v1/betaGroups", body)
  group = resp.to_models.first
  puts "Created internal beta group: #{GROUP_NAME}"
end

TESTERS.each do |tester|
  existing = Spaceship::ConnectAPI.get_beta_testers(
    filter: { betaGroups: group.id, email: tester[:email] }
  ).to_models

  if existing.any?
    puts "Tester already in group: #{tester[:email]}"
    next
  end

  # The bulkBetaTesterAssignments endpoint is not available with API key
  # auth; POST /v1/betaTesters is the official documented endpoint.
  begin
    Spaceship::ConnectAPI.post_beta_tester_assignment(
      beta_group_ids: [group.id],
      attributes: tester
    )
  rescue Spaceship::UnexpectedResponse => e
    abort(
      "Failed to add #{tester[:email]} to #{GROUP_NAME}: #{e.message}\n" \
      "Internal group testers must be App Store Connect team members."
    )
  end

  puts "Added tester to #{GROUP_NAME}: #{tester[:email]}"
end
