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

types = Spaceship::ConnectAPI::Certificate::CertificateType.constants.map do |name|
  Spaceship::ConnectAPI::Certificate::CertificateType.const_get(name)
rescue StandardError
  nil
end.compact.uniq.sort

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
end

keychain_fp = AppleSigningHelpers.keychain_fingerprint
if keychain_fp
  puts "=== CI keychain (BUILD_CERTIFICATE_BASE64) ==="
  puts "  Apple Distribution fingerprint: #{keychain_fp}"
else
  puts "=== CI keychain ==="
  puts "  No Apple Distribution identity imported (setup-apple-signing not run)"
end
