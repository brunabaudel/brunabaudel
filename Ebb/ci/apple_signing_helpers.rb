# frozen_string_literal: true

require "base64"
require "openssl"

module AppleSigningHelpers
  KEYCHAIN_PATH = File.expand_path(
    "#{ENV.fetch('RUNNER_TEMP', '/tmp')}/app-signing.keychain-db"
  )

  module_function

  def keychain_fingerprint
    return nil unless File.exist?(KEYCHAIN_PATH)

    output = `security find-identity -v -p codesigning "#{KEYCHAIN_PATH}" 2>/dev/null`
    match = output.match(/\)\s+([A-F0-9]{40})\s+"Apple Distribution/i)
    match&.[](1)&.upcase
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
