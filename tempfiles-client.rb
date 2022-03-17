#!/usr/bin/env ruby
# frozen_string_literal: true

require 'clipboard'
require 'rest-client'
require 'json'
require 'open-uri'
require 'optparse'
require 'tempfile'

module Settings
  @settings = nil
  @path = "#{Dir.home}/.config/TempFiles/settings.json"

  def self.load
    Settings.download unless File.exists? @path
    file = JSON.parse(File.read(@path))
    @settings = file
  end

  def self.get(name)
    @settings[name]
  end

  def self.download
    url = URI('https://tempfiles.download/settings.json')
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    response = http.request(Net::HTTP::Get.new(url))
    raise 'Unable to download settings' unless response.code == '200'
    begin
    json = JSON.parse(response.body)
    rescue JSON::ParseException => e
      raise 'Downloaded settings contain errors'
    end
    Dir.mkdir(File.dirname(@path)) unless Dir.exists? File.dirname(@path)
    File.open(@path, 'w') do |f|
      f.write(JSON.pretty_generate(json))
    end
  end
end

module TempFiles
  def self.upload(path)
    file = path.start_with?('file://') ? File.new(open(path), 'rb') : File.new(path, 'rb')
    res = RestClient.post(Settings.get('upload url'), file: file)
    res = JSON.parse(res)
    raise 'Upload error' unless res.key?('url')
    res['url']
  end
end

def take_screenshot
  screenshot_name = "screenshot_#{Time.now.getutc.to_i}.png"
  fullpath = File.expand_path("#{Settings.get('local path')}/#{screenshot_name}")
  `import #{@options.include?(:windowed) ? '-window root' : ''} -colorspace rgb #{fullpath}`
  fullpath
end

def write_data(data)
  file = Tempfile.new('tempfiles')
  file.write(data)
  file.rewind
  file.close
  file.path
end

def notify(msg, path)
  `notify-send TempFiles "#{msg}" -i #{path}`
end

###
# Parse arguments
###

ARGV << '-h' if ARGV.empty?
@options = {}
OptionParser.new do |opts|
  opts.on('-s', '--screenshot', 'Take screenshot') do
    @options[:screenshot] = true
  end

  opts.on('-w', '--windowed', 'Capture entire window (requires -s)') do
    @options[:windowed] = true
  end

  opts.on('-u', '--upload', 'Upload file') do
    @options[:upload] = true
  end
end.parse!
raise OptionParser::MissingArgument if (@options.key?(:windowed) && @options[:screenshot].nil?)

###
# Run program
###

Settings.load

if @options.key? :screenshot
  path = take_screenshot
  Clipboard.copy "file://#{path}"
end

if @options.key? :upload
  clipboard = Clipboard.paste
  path = clipboard.start_with?('file://') ? clipboard : write_data(clipboard)
  clipboard.slice!('file://')

  url = TempFiles.upload(path)
  notify('Uploaded!', path) if Settings.get 'notify'
  Clipboard.copy url if Settings.get 'copy'
end
