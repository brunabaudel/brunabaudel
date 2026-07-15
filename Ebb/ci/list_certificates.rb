#!/usr/bin/env ruby
# frozen_string_literal: true

require "spaceship"

require_relative "apple_signing_helpers"

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

types = %w[
  IOS_DEVELOPMENT
  IOS_DISTRIBUTION
  MAC_APP_DEVELOPMENT
  MAC_APP_DISTRIBUTION
  MAC_INSTALLER_DISTRIBUTION
  DEVELOPMENT
  DISTRIBUTION
  DEVELOPER_ID_APPLICATION
  DEVELOPER_ID_APPLICATION_G2
  DEVELOPER_ID_KEXT
  DEVELOPER_ID_KEXT_G2
  APPLE_PAY
  APPLE_PAY_MERCHANT_IDENTITY
  APPLE_PAY_PSP_IDENTITY
  APPLE_PAY_RSA
  IDENTITY_ACCESS
  PASS_TYPE_ID
  PASS_TYPE_ID_WITH_NFC
]

puts "Apple Developer certificates for team (via App Store Connect API)"
puts "API key: #{key_id}"
puts

types.each do |cert_type|
  certs = Spaceship::ConnectAPI::Certificate.all(filter: { certificateType: cert_type })
  next if certs.empty?

  puts "=== #{cert_type} (#{certs.length}) ==="
  certs.each do |cert|
    fp = AppleSigningHelpers.certificate_fingerprint(cert)
    status = cert.valid? ? "valid" : "invalid"
    display_name = cert.display_name || cert.name || "(no name)"
    expires = cert.expiration_date || "unknown"
    puts "  [#{status}] #{display_name}"
    puts "           id:          #{cert.id}"
    puts "           serial:      #{cert.serial_number}" if cert.respond_to?(:serial_number) && cert.serial_number
    puts "           expires:     #{expires}"
    puts "           fingerprint: #{fp || 'unavailable'}"
    puts
  end
rescue Spaceship::UnexpectedResponse => e
  warn "Skipping #{cert_type}: #{e.message.split("\n").first}"
end

keychain_fp = AppleSigningHelpers.keychain_fingerprint
keychain_label = AppleSigningHelpers.keychain_identity_label

puts "=== CI keychain (BUILD_CERTIFICATE_BASE64) ==="
puts "  identity: #{keychain_label || 'not found'}"
puts "  fingerprint: #{keychain_fp || 'not found'}"

if keychain_fp
  ios_distribution = Spaceship::ConnectAPI::Certificate.all(
    filter: { certificateType: Spaceship::ConnectAPI::Certificate::CertificateType::IOS_DISTRIBUTION }
  )
  match = ios_distribution.find do |cert|
    AppleSigningHelpers.certificate_fingerprint(cert) == keychain_fp
  end

  if match
    status = match.valid? ? "valid" : "invalid"
    puts "  MATCH: #{status} IOS_DISTRIBUTION #{match.display_name || match.id}"
  else
    puts "  NO MATCH among IOS_DISTRIBUTION certificates on this Apple account"
  end
else
  puts "  Could not read a distribution signing identity from the imported .p12"
end
