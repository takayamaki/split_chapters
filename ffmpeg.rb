# frozen_string_literal: true

require 'pathname'

module FFMpeg
  BASE_COMMAND = 'bin\ffmpeg.exe -y -hide_banner -loglevel error -stats -hwaccel qsv'
  ENCODE_OPTIONS = '-vcodec libx264 -preset veryslow -b:v 8192k -acodec aac -b:a 128k -map 0:v:0 -map 0:a:0 -pix_fmt yuv420p'
  MIN_DURATION = 60
  MAX_DURATION = 600

  class << self
    def output_commands(video)
      seq_number_digits = video.chapters.length.to_s.length
      video.chapters.each.with_index(1).flat_map do |chapter, seq_number|
        formatted_seq_number = format("%0#{seq_number_digits}d", seq_number)
        commands = [
          two_pass_encode_1st_pass(chapter, video.file_path),
          two_pass_encode_2nd_pass(chapter, video.file_path, formatted_seq_number)
        ]

        commands.map! { "@rem #{_1}" } unless (MIN_DURATION..MAX_DURATION).include?(chapter.duration)
        commands
      end
    end

    def two_pass_encode_1st_pass(chapter, path)
      [
        BASE_COMMAND,
        seek_integer_part_option(chapter),
        input_file_option(path),
        seek_fractional_part_option(chapter),
        duration_option(chapter),
        ENCODE_OPTIONS,
        '-pass 1 -f null',
        'nul'
      ].join(' ')
    end

    def two_pass_encode_2nd_pass(chapter, path, seq_number)
      [
        BASE_COMMAND,
        seek_integer_part_option(chapter),
        input_file_option(path),
        seek_fractional_part_option(chapter),
        duration_option(chapter),
        ENCODE_OPTIONS,
        '-pass 2 -movflags +faststart',
        "\"#{convert_to_win_path(build_output_path(path, seq_number))}\""
      ].join(' ')
    end

    def seek_integer_part_option(chapter)
      "-ss #{chapter.start_at_integer_part}"
    end

    def seek_fractional_part_option(chapter)
      "-ss #{chapter.start_at_fractional_part.to_f}"
    end

    def duration_option(chapter)
      "-t #{chapter.duration.to_f}"
    end

    def input_file_option(path)
      "-i \"#{convert_to_win_path(path)}\""
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
