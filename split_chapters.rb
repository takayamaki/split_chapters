#!/bin/env ruby
# frozen_string_literal: true

require_relative 'video'
require_relative 'ffmpeg'

USAGE = <<~TEXT
  Usage: split_chapters [OPTION]... FILE...
  Write a Windows batch file to standard output that encodes each chapter of
  FILE(s) into a separate mp4 (x264 crf 18, or 2-pass abr 8192k when crf 18
  would exceed 8 Mbps).

    -h, --help            display this help and exit
    --min-duration SECS   write chapters shorter than SECS as @rem (default 60; 0 = none)
    --max-duration SECS   write chapters longer than SECS as @rem (default none)

  Output of several runs can be appended (>>) to a single batch file.

  Examples:
    split_chapters disc1.mkv  > /mnt/d/encode.bat
    split_chapters disc2.mkv >> /mnt/d/encode.bat
TEXT

if ARGV.empty?
  warn USAGE
  exit 1
end
if ARGV.intersect?(%w[-h --help])
  puts USAGE
  exit 0
end

options = { min_duration: FFMpeg::MIN_DURATION, max_duration: FFMpeg::MAX_DURATION }
args = ARGV.dup
%w[--min-duration --max-duration].each do |flag|
  next unless (i = args.index(flag))

  value = args[i + 1]
  unless value&.match?(/\A\d+(\.\d+)?\z/)
    warn "split_chapters: #{flag} needs a number of seconds"
    exit 1
  end
  options[flag.delete_prefix('--').tr('-', '_').to_sym] = value.to_f
  args.slice!(i, 2)
end

file_paths = args.map do |path|
  absolute_path = File.expand_path(path)
  unless File.exist?(absolute_path)
    warn "split_chapters: cannot access '#{path}': No such file or directory"
    exit 1
  end

  absolute_path
end

videos = file_paths.map do |path|
  chapters = FFProve.chapters(path)
  Video.new(path, chapters, **FFProve.frame_rates(path))
end

lines = [
  'chcp 65001',
  *FFMpeg.header,
  *videos.flat_map { |video| FFMpeg.output_commands(video, **options) },
  *videos.flat_map { |video| FFMpeg.remove_2pass_log_commands(video.file_path) },
  *FFMpeg.footer
]
lines.each { print "#{_1}\r\n" }
