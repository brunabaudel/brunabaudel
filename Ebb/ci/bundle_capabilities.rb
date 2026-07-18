# frozen_string_literal: true

require "spaceship"

module EbbBundleCapabilities
  BUNDLE_ID = "com.bcbs.ebb"

  HEALTHKIT = Spaceship::ConnectAPI::BundleIdCapability::Type::HEALTHKIT
  ICLOUD = Spaceship::ConnectAPI::BundleIdCapability::Type::ICLOUD
  ICLOUD_VERSION = Spaceship::ConnectAPI::BundleIdCapability::Settings::ICLOUD_VERSION
  XCODE_6 = Spaceship::ConnectAPI::BundleIdCapability::Options::XCODE_6

  ICLOUD_SETTINGS = [{
    key: ICLOUD_VERSION,
    options: [{ key: XCODE_6 }]
  }].freeze

  module_function

  def ensure_healthkit!(bundle)
    return if bundle.get_capabilities.any? { |cap| cap.is_type?(HEALTHKIT) }

    bundle.create_capability(HEALTHKIT)
    puts "Enabled HealthKit capability on #{BUNDLE_ID}"
  end

  def ensure_icloud!(bundle)
    capability = bundle.get_capabilities.find { |cap| cap.is_type?(ICLOUD) }
    if capability.nil?
      bundle.create_capability(ICLOUD, settings: ICLOUD_SETTINGS)
      puts "Enabled iCloud (CloudKit) capability on #{BUNDLE_ID}"
      return
    end

    bundle.update_capability(ICLOUD, enabled: true, settings: ICLOUD_SETTINGS)
    puts "Ensured iCloud (CloudKit) capability on #{BUNDLE_ID}"
  end

  def ensure_all!(bundle)
    ensure_healthkit!(bundle)
    ensure_icloud!(bundle)
  end
end
