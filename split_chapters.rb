#!/bin/env ruby
# frozen_string_literal: true

require_relative './video'
require_relative './ffmpeg'

file_paths = ARGV.map do |path|
  absolute_path = File.expand_path(path)
  raise 'No such file' unless File.exist?(absolute_path)

  absolute_path
end

videos = file_paths.map do |path|
  chapters = FFProve.chapters(path)
  Video.new(path, chapters)
end

print "chcp 65001\r\n"
videos.flat_map { |video| FFMpeg.output_commands(video) }.each { print "#{_1}\r\n" }
videos.flat_map { |video| FFMpeg.remove_2pass_log_commands(video.file_path) }.each { print "#{_1}\r\n" }
