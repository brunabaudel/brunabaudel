#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "jwt"
require "net/http"
require "openssl"
require "uri"

BUNDLE_ID = "com.brunabaudel.BasicApp"
APP_NAME = "BasicApp"
SKU = "basicapp001"

key_id = ENV.fetch("APPSTORE_API_KEY_ID")
issuer_id = ENV.fetch("APPSTORE_ISSUER_ID")
key_content = ENV.fetch("APPSTORE_API_PRIVATE_KEY").gsub("\r\n", "\n").strip

private_key = OpenSSL::PKey.read(key_content)
token = JWT.encode(
  {
    iss: issuer_id,
    iat: Time.now.to_i,
    exp: Time.now.to_i + 1200,
    aud: "appstoreconnect-v1"
  },
  private_key,
  "ES256",
  header_fields: { kid: key_id, typ: "JWT" }
)

def request(method, path, token, body = nil)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  klass = method == :get ? Net::HTTP::Get : Net::HTTP::Post
  req = klass.new(uri)
  req["Authorization"] = "Bearer #{token}"
  req["Content-Type"] = "application/json"
  req.body = body.to_json if body

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
  parsed = response.body.empty? ? {} : JSON.parse(response.body)
  [response.code.to_i, parsed]
end

code, apps = request(:get, "/v1/apps?filter[bundleId]=#{BUNDLE_ID}", token)
abort("Auth failed checking apps (#{code}): #{apps}") unless code == 200

if apps["data"]&.any?
  puts "App Store Connect app already exists for #{BUNDLE_ID}"
  exit 0
end

code, created_app = request(:post, "/v1/apps", token, {
  data: {
    type: "apps",
    attributes: {
      name: APP_NAME,
      bundleId: BUNDLE_ID,
      sku: SKU,
      primaryLocale: "en-US"
    }
  }
})

if code == 201
  puts "Created App Store Connect app #{APP_NAME}"
  exit 0
end

detail = created_app.dig("errors", 0, "detail").to_s
if detail.include?("already") || detail.include?("exists")
  puts "App Store Connect app already exists"
  exit 0
end

abort("Failed to create App Store Connect app (#{code}): #{created_app}")
exit 1
