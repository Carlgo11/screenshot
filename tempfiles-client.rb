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

  def self.load
    path = 'settings.json'
    dir = File.dirname(path)
    unless File.directory?(dir)
      FileUtils.mkdir_p(dir)
    end
    file = JSON.parse(File.read(path))
    @settings = file
  end

  def self.get(name)
    @settings[name]
  end

  def self.download

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

