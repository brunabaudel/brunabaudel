#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "fileutils"
require "spaceship"

require_relative "apple_signing_helpers"
require_relative "bundle_capabilities"

BUNDLE_ID = EbbBundleCapabilities::BUNDLE_ID
PROFILE_NAME = "Ebb App Store CI"
ICLOUD_CONTAINER = "iCloud.com.bcbs.ebb"

def decoded_profile_content(profile)
  return "" if profile.profile_content.to_s.empty?

  Base64.decode64(profile.profile_content)
end

def profile_includes_healthkit?(profile)
  decoded_profile_content(profile).include?("com.apple.developer.healthkit")
end

def profile_includes_icloud?(profile)
  content = decoded_profile_content(profile)
  content.include?("com.apple.developer.icloud-services") &&
    content.include?("com.apple.developer.icloud-container-identifiers") &&
    content.include?(ICLOUD_CONTAINER)
end

def profile_includes_push?(profile)
  decoded_profile_content(profile).include?("aps-environment")
end

def fetch_app_store_profiles
  Spaceship::ConnectAPI::Profile.all(
    filter: {
      profileType: Spaceship::ConnectAPI::Profile::ProfileType::IOS_APP_STORE
    },
    includes: "bundleId,certificates"
  ).select { |profile| profile.bundle_id&.identifier == BUNDLE_ID }
end

def delete_profile!(profile)
  puts "Deleting App Store profile: #{profile.name} (#{profile.uuid}, valid=#{profile.valid?})"
  profile.delete!
end

def delete_profiles!(profiles)
  profiles.each { |profile| delete_profile!(profile) }
end

def find_usable_profile(profiles, distribution_cert)
  profiles.find do |candidate|
    candidate.valid? &&
      candidate.certificates&.any? { |cert| cert.id == distribution_cert.id } &&
      profile_includes_healthkit?(candidate) &&
      profile_includes_icloud?(candidate) &&
      profile_includes_push?(candidate)
  end
end

def create_app_store_profile!(bundle, distribution_cert)
  attempts = 3
  attempts.times do |attempt|
    begin
      return Spaceship::ConnectAPI::Profile.create(
        name: PROFILE_NAME,
        profile_type: Spaceship::ConnectAPI::Profile::ProfileType::IOS_APP_STORE,
        bundle_id_id: bundle.id,
        certificate_ids: [distribution_cert.id]
      )
    rescue Spaceship::UnexpectedResponse => e
      raise unless e.message.include?("Multiple profiles found") || e.message.include?("409")

      puts "Profile name conflict — removing duplicates named #{PROFILE_NAME} (attempt #{attempt + 1}/#{attempts})"
      delete_profiles!(fetch_app_store_profiles.select { |profile| profile.name == PROFILE_NAME })
      sleep 2
    end
  end

  abort("Failed to create App Store profile #{PROFILE_NAME} after #{attempts} attempts")
end

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

EbbBundleCapabilities.ensure_all!(bundle)

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

all_profiles = fetch_app_store_profiles
profile = find_usable_profile(all_profiles, distribution_cert)

unless profile
  stale_profiles = all_profiles.reject do |candidate|
    candidate.valid? &&
      candidate.certificates&.any? { |cert| cert.id == distribution_cert.id } &&
      profile_includes_healthkit?(candidate) &&
      profile_includes_icloud?(candidate) &&
      profile_includes_push?(candidate)
  end

  if stale_profiles.any?
    puts "Removing #{stale_profiles.size} stale App Store profile(s) for #{BUNDLE_ID}"
    delete_profiles!(stale_profiles)
  end

  puts "Creating App Store provisioning profile: #{PROFILE_NAME}"
  profile = create_app_store_profile!(bundle, distribution_cert)
else
  puts "Reusing App Store provisioning profile: #{profile.name} (#{profile.uuid})"
end

abort("Provisioning profile has no content") if profile.profile_content.to_s.empty?

unless profile_includes_healthkit?(profile)
  abort(
    "Provisioning profile still missing HealthKit entitlement after regeneration. " \
    "Enable HealthKit on #{BUNDLE_ID} in Apple Developer → Identifiers, then re-run."
  )
end

unless profile_includes_icloud?(profile)
  abort(
    "Provisioning profile still missing iCloud container #{ICLOUD_CONTAINER}. " \
    "In Apple Developer → Identifiers: create iCloud container #{ICLOUD_CONTAINER}, " \
    "open App ID #{BUNDLE_ID} → iCloud → Include CloudKit support → select that container, " \
    "then re-run TestFlight."
  )
end

unless profile_includes_push?(profile)
  abort(
    "Provisioning profile still missing Push Notifications (aps-environment). " \
    "Enable Push Notifications on #{BUNDLE_ID} in Apple Developer → Identifiers, then re-run TestFlight."
  )
end

profile_bytes = Base64.decode64(profile.profile_content)
profile_path = File.join(profiles_dir, "#{profile.uuid}.mobileprovision")

FileUtils.mkdir_p(profiles_dir)
File.write(profile_path, profile_bytes)

puts "Installed provisioning profile at #{profile_path}"
puts "PROFILE_UUID=#{profile.uuid}"
puts "PROFILE_NAME=#{profile.name}"
