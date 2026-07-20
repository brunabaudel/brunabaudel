# frozen_string_literal: true

require "base64"
require "openssl"

module AppleSigningHelpers
  KEYCHAIN_PATH = File.expand_path(
    "#{ENV.fetch('RUNNER_TEMP', '/tmp')}/app-signing.keychain-db"
  )
  LOGIN_KEYCHAIN_PATH = File.expand_path("~/Library/Keychains/login.keychain-db")

  module_function

  def keychain_paths
    [KEYCHAIN_PATH, LOGIN_KEYCHAIN_PATH].select { |path| File.exist?(path) }
  end

  def keychain_fingerprint
    keychain_paths.each do |path|
      output = `security find-identity -v -p codesigning "#{path}" 2>/dev/null`
      match = output.match(/\)\s+([A-F0-9]{40})\s+"(?:Apple|iPhone) Distribution/i)
      return match[1].upcase if match

      # Fall back to the first codesigning identity for diagnostics.
      any = output.match(/\)\s+([A-F0-9]{40})\s+"/i)
      return any[1].upcase if any
    end

    nil
  end

  def keychain_identity_label
    keychain_paths.each do |path|
      output = `security find-identity -v -p codesigning "#{path}" 2>/dev/null`
      match = output.match(/\)\s+[A-F0-9]{40}\s+"(.+)"$/i)
      return match[1] if match
    end

    nil
  end

  def certificate_fingerprint(cert)
    content = Base64.decode64(cert.certificate_content.to_s)
    return nil if content.empty?

    OpenSSL::Digest::SHA1.hexdigest(content).upcase
  end

  def find_distribution_cert_matching_keychain(certs)
    fingerprint = keychain_fingerprint
    unless fingerprint
      abort(
        "No Apple Distribution identity in the CI keychain. " \
        "Run setup-apple-signing with BUILD_CERTIFICATE_BASE64 before this step."
      )
    end

    certs.find do |cert|
      certificate_fingerprint(cert) == fingerprint
    end
  end
end
