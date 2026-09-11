# frozen_string_literal: true

require 'pathname'

module FFMpeg
  BASE_COMMAND = 'bin\ffmpeg.exe -y -hide_banner -loglevel error -stats'
  ENCODE_OPTIONS = '-vcodec libx264 -preset veryslow -b:v 8192k -acodec aac -b:a 128k -map 0:v:0 -map 0:a:0 -pix_fmt yuv420p'
  MIN_DURATION = 60
  MAX_DURATION = 600

  HEADER = <<~BAT
    @echo off
    setlocal
    cd /d %~dp0

    rem ==== tunables ==========================================================
    set "CRF=18"
    rem  LIMIT : TOTAL container bitrate in kbps (video 8192 + audio 128)
    set "LIMIT=8320"
    set "ABRBV=8192k"
    set "CRFCAP=-maxrate 20000k -bufsize 40000k"
    rem  PROBETHR : video kbps reported by x264 after the crf pass 1 ("kb/s:").
    rem             above this the crf attempt is skipped and we go straight to
    rem             pass 2. pass 1 over-reports by +2..+23% on <8.5Mbps material
    rem             and under-reports by up to -9% on high bitrate material, so
    rem             keep ~5% margin below the 8192 video limit.
    set "PROBETHR=7800"
    rem ========================================================================
    set "PROBE=%TEMP%\\split_chapters_probe.txt"
    set /a LIMITBPS=%LIMIT%*1000
  BAT

  class << self
    def header
      HEADER.lines(chomp: true)
    end

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
