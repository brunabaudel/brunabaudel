#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "tmpdir"

ipa_path = ARGV.fetch(0)
abort("IPA not found: #{ipa_path}") unless File.exist?(ipa_path)

Dir.mktmpdir("ebb-ipa-") do |tmpdir|
  _stdout, stderr, status = Open3.capture3("unzip", "-q", ipa_path, "-d", tmpdir)
  abort("unzip failed: #{stderr}") unless status.success?

  app_path = Dir.glob(File.join(tmpdir, "Payload", "*.app")).first
  abort("No .app bundle found inside IPA") unless app_path

  entitlements_xml, stderr, status = Open3.capture3(
    "codesign", "-d", "--entitlements", ":-", app_path
  )
  abort("codesign failed: #{stderr}") unless status.success?

  entitlements_path = File.join(tmpdir, "entitlements.plist")
  File.write(entitlements_path, entitlements_xml)

  read = lambda do |key|
    stdout, stderr, ok = Open3.capture3(
      "/usr/libexec/PlistBuddy", "-c", "Print :#{key}", entitlements_path
    )
    abort("PlistBuddy failed for #{key}: #{stderr}") unless ok.success?

    stdout.strip
  end

  aps = read.call("aps-environment")
  cloudkit_env = read.call("com.apple.developer.icloud-container-environment")
  containers = read.call("com.apple.developer.icloud-container-identifiers")

  puts "Signed app entitlements:"
  puts "  aps-environment=#{aps}"
  puts "  icloud-container-environment=#{cloudkit_env}"
  puts "  icloud-containers=#{containers}"

  errors = []
  errors << "aps-environment must be production (got #{aps})" unless aps == "production"
  errors << "icloud-container-environment must be Production (got #{cloudkit_env})" unless cloudkit_env == "Production"
  errors << "missing iCloud.com.bcbs.ebb container" unless containers.include?("iCloud.com.bcbs.ebb")

  if errors.empty?
    puts "Release entitlements look correct for TestFlight CloudKit sync."
  else
    abort("Release entitlements check failed:\n- #{errors.join("\n- ")}")
  end
end
