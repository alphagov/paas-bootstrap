#!/usr/bin/env ruby
require 'English'
require 'openssl'
require 'json'
require 'date'

def separator
  puts('-' * 80)
end

class String
  def red
    "\e[31m#{self}\e[0m"
  end

  def green
    "\e[32m#{self}\e[0m"
  end

  def yellow
    "\e[33m#{self}\e[0m"
  end

  def blue;
    "\e[34m#{self}\e[0m"
  end
end

class CredHubClient
  attr_reader :api_url

  def initialize(api_url)
    @api_url = api_url
  end

  def certificates
    body = `credhub curl -p '#{api_url}/certificates'`
    raise body unless $CHILD_STATUS.success?
    JSON.parse(body).fetch('certificates')
  end

  def current_certificate(name)
    body = `credhub curl -p '#{api_url}/data?name=#{name}&current=true'`
    raise body unless $CHILD_STATUS.success?
    JSON.parse(body).fetch('data').first
  end

  def transitional_certificates(name)
    body = `credhub curl -p '#{api_url}/certificates?name=#{name}'`
    raise body unless $CHILD_STATUS.success?
    JSON
      .parse(body)
      .fetch('certificates').first.fetch('versions')
      .select { |c| c.fetch('transitional', false) }
  end

  def live_certificates(name)
    current = current_certificate(name)
    transitional = transitional_certificates(name)
    transitional.concat([current]).uniq { |c| c.fetch('id') }
  end

  def credential(credential_id)
    body = `credhub curl -p '#{api_url}/data/#{credential_id}'`
    raise body unless $CHILD_STATUS.success?
    JSON.parse(body)
  end
end

ALERT_DAYS = (ARGV[0] || '15').to_i
CREDHUB_SERVER = ENV.fetch('CREDHUB_SERVER')
alert = false
api_url = "#{CREDHUB_SERVER}/v1"

separator

client = CredHubClient.new(api_url)
certs = client.certificates.reject { |c| c['name'].match?(/_old$/) }

transitional_certificate_names = []
expiring_certificate_names = []

certs.each do |cert|
  live_certs = client.live_certificates(cert['name'])

  live_certs.each do |live_cert|
    cred = client.credential(live_cert['id'])

    xcert = OpenSSL::X509::Certificate.new cred.dig('value', 'certificate')

    days_to_expire = ((xcert.not_after - Time.now) / (24 * 3600)).floor

    alert = true unless days_to_expire > ALERT_DAYS

    transitional_status = live_cert['transitional'] ? 'transitional'.yellow : 'non-transitional'.blue
    danger_status = days_to_expire > ALERT_DAYS ? 'OK'.green : 'DANGER'.red

    puts "#{live_cert['name'].yellow} has #{days_to_expire} days to expire (#{transitional_status}) (#{danger_status})"

    unless xcert.extensions.find { |e| e.oid == 'subjectKeyIdentifier' }
      puts "#{live_cert['name']}: ERROR! Missing Subject Key Identifier".red
      alert = true
    end

    unless days_to_expire > ALERT_DAYS
      expiring_certificate_names << live_cert['name']
    end

    if live_cert['transitional']
      transitional_certificate_names << live_cert['name']
    end
  end
end

unless transitional_certificate_names.empty?
  separator

  puts 'The following certificates are transitional and are going to update instances:'

  transitional_certificate_names.each do |cert|
    puts cert.yellow
  end
end

unless expiring_certificate_names.empty?
  separator

  puts 'The following certificates are expiring and require operator intervention:'

  expiring_certificate_names.each do |cert|
    puts cert.red
  end
end

separator

exit 1 if alert
