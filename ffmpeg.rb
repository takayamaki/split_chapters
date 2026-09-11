# frozen_string_literal: true

require 'pathname'

module FFMpeg
  BASE_COMMAND = 'bin\ffmpeg.exe -y -hide_banner -loglevel error -stats'
  ENCODE_OPTIONS = '-vcodec libx264 -preset veryslow -b:v 8192k -acodec aac -b:a 128k -map 0:v:0 -map 0:a:0 -pix_fmt yuv420p'
  MIN_DURATION = 60
  MAX_DURATION = 600

  class << self
    def output_commands(video)
      seq_number_digits = video.chapters.length.to_s.length
      video.chapters.each.with_index(1).map do |chapter, seq_number|
        formatted_seq_number = format("%0#{seq_number_digits}d", seq_number)
        command = encode_call(chapter, video.file_path, formatted_seq_number)
        (MIN_DURATION..MAX_DURATION).include?(chapter.duration) ? command : "@rem #{command}"
      end
    end

    def remove_2pass_log_commands(src_path)
      [
        "del \"#{stats_file_name(src_path)}\"",
        "del \"#{stats_file_name(src_path)}.mbtree\""
      ]
    end

    # call :encode <src> <ss int> <ss frac> <duration> <dst> <stats file>
    def encode_call(chapter, path, seq_number)
      [
        'call :encode',
        "\"#{convert_to_win_path(path)}\"",
        chapter.start_at_integer_part,
        chapter.start_at_fractional_part.to_f,
        chapter.duration.to_f,
        "\"#{convert_to_win_path(build_output_path(path, seq_number))}\"",
        "\"#{stats_file_name(path)}\""
      ].join(' ')
    end

    def stats_file_name(src_path)
      src_path = Pathname(src_path)
      "#{src_path.basename(src_path.extname)}.log"
    end

    def build_output_path(src_path, seq_number)
      src_path = Pathname(src_path)

      [
        src_path.dirname,
        '/',
        "#{src_path.basename(src_path.extname)}_#{seq_number}",
        '.mp4'
      ].join
    end

    def convert_to_win_path(path)
      path.sub(%r{/mnt/([a-z])/}) { "#{Regexp.last_match(1).upcase}:\\" }.gsub('/', '\\')
    end
  end
end
