#!/usr/bin/env ruby
# frozen_string_literal: true

require "spaceship"

# Ephemeral GitHub runners with CODE_SIGN_STYLE=Automatic and
# -allowProvisioningUpdates mint IOS_DEVELOPMENT certificates on every run.
# Apple caps certificates per account, which eventually breaks archives.
#
# This script revokes IOS_DEVELOPMENT certificates (not needed for TestFlight
# archives) and trims excess IOS_DISTRIBUTION certificates only when the
# account is over Apple's limit. Manual CI signing reuses one stored .p12.

MAX_DISTRIBUTION_CERTS = 2

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

def revoke_certificates(certs, label)
  certs.each do |cert|
    display_name = cert.display_name || cert.name || cert.id
    puts "Revoking #{label}: #{display_name} (#{cert.id})"
    cert.delete!
  end
end

development_certs = Spaceship::ConnectAPI::Certificate.all(
  filter: { certificateType: Spaceship::ConnectAPI::Certificate::CertificateType::IOS_DEVELOPMENT }
)

if development_certs.empty?
  puts "No IOS_DEVELOPMENT certificates to revoke"
else
  puts "Revoking #{development_certs.length} IOS_DEVELOPMENT certificate(s)"
  revoke_certificates(development_certs, "IOS_DEVELOPMENT")
end

distribution_certs = Spaceship::ConnectAPI::Certificate.all(
  filter: { certificateType: Spaceship::ConnectAPI::Certificate::CertificateType::IOS_DISTRIBUTION }
).select(&:valid?)

distribution_certs.sort_by! { |cert| cert.expiration_date || "" }.reverse!

if distribution_certs.length <= MAX_DISTRIBUTION_CERTS
  puts "Keeping #{distribution_certs.length} IOS_DISTRIBUTION certificate(s)"
else
  keep = distribution_certs.first(MAX_DISTRIBUTION_CERTS)
  revoke = distribution_certs.drop(MAX_DISTRIBUTION_CERTS)

  keep.each do |cert|
    display_name = cert.display_name || cert.name || cert.id
    puts "Keeping IOS_DISTRIBUTION: #{display_name} (#{cert.id})"
  end

  puts "Revoking #{revoke.length} extra IOS_DISTRIBUTION certificate(s) over the #{MAX_DISTRIBUTION_CERTS}-cert limit"
  revoke_certificates(revoke, "IOS_DISTRIBUTION")
end
