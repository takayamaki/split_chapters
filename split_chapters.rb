require_relative './video'

file_paths = ARGV.map do |path|
  absolute_path = File.expand_path(path)
  raise 'No such file' unless File.exist?(absolute_path)
  absolute_path
end

videos = file_paths.map do |path|
  chapters = FFProve.chapters(path)
  Video.new(path, chapters)
end

pp videos
