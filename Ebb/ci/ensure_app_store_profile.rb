#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "fileutils"
require "spaceship"

require_relative "apple_signing_helpers"

BUNDLE_ID = "com.bcbs.ebb"
PROFILE_NAME = "Ebb App Store CI"

key_id = ENV.fetch("APPSTORE_API_KEY_ID")
issuer_id = ENV.fetch("APPSTORE_ISSUER_ID")
key_path = File.expand_path(
  "~/.appstoreconnect/private_keys/AuthKey_#{key_id}.p8"
)
profiles_dir = File.expand_path("~/Library/MobileDevice/Provisioning Profiles")

abort("API key file not found: #{key_path}") unless File.exist?(key_path)

Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
  key_id: key_id,
  issuer_id: issuer_id,
  filepath: key_path
)

bundle = Spaceship::ConnectAPI::BundleId.find(BUNDLE_ID)
abort("Bundle ID not found: #{BUNDLE_ID}") unless bundle

distribution_certs = Spaceship::ConnectAPI::Certificate.all(
  filter: { certificateType: Spaceship::ConnectAPI::Certificate::CertificateType::IOS_DISTRIBUTION }
).select(&:valid?)

distribution_cert = AppleSigningHelpers.find_distribution_cert_matching_keychain(
  distribution_certs
)

unless distribution_cert
  abort(
    "No valid IOS_DISTRIBUTION certificate on the Apple account matches " \
    "BUILD_CERTIFICATE_BASE64. Re-export the .p12 from Keychain Access and update the secret."
  )
end

puts "Using IOS_DISTRIBUTION certificate: #{distribution_cert.display_name || distribution_cert.id}"

profiles = Spaceship::ConnectAPI::Profile.all(
  filter: {
    profileType: Spaceship::ConnectAPI::Profile::ProfileType::IOS_APP_STORE
  },
  includes: "bundleId,certificates"
).select do |profile|
  profile.bundle_id&.identifier == BUNDLE_ID && profile.valid?
end

profile = profiles.find do |candidate|
  candidate.certificates&.any? { |cert| cert.id == distribution_cert.id }
end

unless profile
  puts "Creating App Store provisioning profile: #{PROFILE_NAME}"
  profile = Spaceship::ConnectAPI::Profile.create(
    name: PROFILE_NAME,
    profile_type: Spaceship::ConnectAPI::Profile::ProfileType::IOS_APP_STORE,
    bundle_id_id: bundle.id,
    certificate_ids: [distribution_cert.id]
  )
else
  puts "Reusing App Store provisioning profile: #{profile.name} (#{profile.uuid})"
end

abort("Provisioning profile has no content") if profile.profile_content.to_s.empty?

profile_bytes = Base64.decode64(profile.profile_content)
profile_path = File.join(profiles_dir, "#{profile.uuid}.mobileprovision")

FileUtils.mkdir_p(profiles_dir)
File.write(profile_path, profile_bytes)

puts "Installed provisioning profile at #{profile_path}"
puts "PROFILE_UUID=#{profile.uuid}"
puts "PROFILE_NAME=#{profile.name}"
