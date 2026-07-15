#!/usr/bin/env ruby
# frozen_string_literal: true

require "spaceship"

require_relative "apple_signing_helpers"

# Ephemeral GitHub runners with CODE_SIGN_STYLE=Automatic and
# -allowProvisioningUpdates mint IOS_DEVELOPMENT certificates on every run.
# Apple caps certificates per account, which eventually breaks archives.
#
# This script revokes IOS_DEVELOPMENT certificates (not needed for TestFlight
# archives) and verifies BUILD_CERTIFICATE_BASE64 matches a valid IOS_DISTRIBUTION
# certificate. Extra IOS_DISTRIBUTION certificates are reported but never revoked.

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
  rescue Spaceship::AccessForbiddenError => e
    warn "Skipping #{label} #{cert.id}: #{e.message.split("\n").first}"
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

keep_cert = AppleSigningHelpers.find_distribution_cert_matching_keychain(distribution_certs)

unless keep_cert
  keychain_fp = AppleSigningHelpers.keychain_fingerprint
  all_distribution = Spaceship::ConnectAPI::Certificate.all(
    filter: { certificateType: Spaceship::ConnectAPI::Certificate::CertificateType::IOS_DISTRIBUTION }
  )

  puts "Keychain Apple Distribution fingerprint: #{keychain_fp || 'not found'}"
  all_distribution.each do |cert|
    fp = AppleSigningHelpers.certificate_fingerprint(cert)
    status = cert.valid? ? "valid" : "invalid"
    display_name = cert.display_name || cert.name || cert.id
    puts "  #{status} IOS_DISTRIBUTION: #{display_name} (#{cert.id}) fingerprint=#{fp}"
  end

  revoked_match = all_distribution.find do |cert|
    !cert.valid? &&
      AppleSigningHelpers.certificate_fingerprint(cert) == keychain_fp
  end

  if revoked_match
    abort(
      "BUILD_CERTIFICATE_BASE64 matches a revoked or expired IOS_DISTRIBUTION certificate " \
      "(#{revoked_match.id}). Create a new Apple Distribution certificate in Apple Developer, " \
      "export its .p12 with private key, and update BUILD_CERTIFICATE_BASE64."
    )
  end

  abort(
    "The Apple Distribution certificate in BUILD_CERTIFICATE_BASE64 does not match " \
    "any valid IOS_DISTRIBUTION certificate on the Apple Developer account. " \
    "Export the .p12 for an existing distribution cert or create one, then update the secret."
  )
end

display_name = keep_cert.display_name || keep_cert.name || keep_cert.id
puts "Using IOS_DISTRIBUTION for CI: #{display_name} (#{keep_cert.id})"

extra_distribution = distribution_certs.reject { |cert| cert.id == keep_cert.id }

if extra_distribution.empty?
  puts "No other valid IOS_DISTRIBUTION certificates on this account"
else
  puts "Warning: #{extra_distribution.length} other valid IOS_DISTRIBUTION certificate(s) on this account (not revoked):"
  extra_distribution.each do |cert|
    name = cert.display_name || cert.name || cert.id
    fp = AppleSigningHelpers.certificate_fingerprint(cert)
    puts "  - #{name} (#{cert.id}) fingerprint=#{fp}"
  end
end
