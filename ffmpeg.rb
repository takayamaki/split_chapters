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

  # :encode subroutine. pass 1 (crf) doubles as the bitrate probe and as the
  # 2-pass stats: below PROBETHR we try a single crf pass, otherwise (or when
  # the crf output still exceeds LIMIT) pass 2 abr reuses the same stats.
  # worst case costs pass1 + crf + pass2, the same as a plain crf -> 2-pass.
  FOOTER = <<~'BAT'
    exit /b 0


    rem ==== :encode <src> <ss int> <ss frac> <duration> <dst> <stats file> ====
    :encode
    echo.
    echo ==== %~n5
    set "BRK="

    rem  the "kb/s:" summary line is only printed at -loglevel info, so stderr
    rem  goes to the probe file and no progress is shown during pass 1.
    echo   [1/2] pass 1 (crf %CRF% probe) ...
    bin\ffmpeg.exe -y -hide_banner -loglevel info -nostats -ss %2 -i "%~1" -ss %3 -t %4 -vcodec libx264 -preset veryslow -crf %CRF% %CRFCAP% -an -map 0:v:0 -pix_fmt yuv420p -x264-params stats="%~6" -pass 1 -f null nul 2> "%PROBE%"
    if errorlevel 1 goto :failed

    set "P1K="
    for /f "tokens=2 delims=:" %%k in ('findstr /c:"kb/s:" "%PROBE%"') do set "P1K=%%k"
    for /f "tokens=1 delims=. " %%k in ("%P1K%") do set "P1K=%%k"
    if not defined P1K goto :abrpass2
    echo %P1K%| findstr /r "^[0-9][0-9]*$" >nul || goto :abrpass2
    if %P1K% LEQ %PROBETHR% goto :crfpass
    echo   [--] probe %P1K% kbps ^> %PROBETHR% kbps  -^> skip crf, 2-pass abr
    goto :abrpass2

    :crfpass
    echo   [2/2] probe %P1K% kbps ^<= %PROBETHR% kbps  -^> crf %CRF% ...
    bin\ffmpeg.exe -y -hide_banner -loglevel error -stats -ss %2 -i "%~1" -ss %3 -t %4 -vcodec libx264 -preset veryslow -crf %CRF% %CRFCAP% -acodec aac -b:a 128k -map 0:v:0 -map 0:a:0 -pix_fmt yuv420p -movflags +faststart "%~5"
    if errorlevel 1 goto :failed

    set "BR="
    bin\ffprobe.exe -v error -show_entries format=bit_rate -of default=nw=1:nk=1 "%~5" > "%PROBE%" 2>nul
    set /p BR=<"%PROBE%"
    if not defined BR goto :abrpass2
    echo %BR%| findstr /r "^[0-9][0-9]*$" >nul || goto :abrpass2
    set /a BRK=%BR%/1000
    if %BR% GTR %LIMITBPS% goto :abrpass2
    echo   [ok ] %BRK% kbps ^<= %LIMIT% kbps  -^> adopt crf
    exit /b 0

    :abrpass2
    if defined BRK echo   [--] %BRK% kbps ^> %LIMIT% kbps  -^> fall back to 2-pass abr
    echo   [2/2] pass 2 abr %ABRBV% ...
    bin\ffmpeg.exe -y -hide_banner -loglevel error -stats -ss %2 -i "%~1" -ss %3 -t %4 -vcodec libx264 -preset veryslow -b:v %ABRBV% -acodec aac -b:a 128k -map 0:v:0 -map 0:a:0 -pix_fmt yuv420p -x264-params stats="%~6" -pass 2 -movflags +faststart "%~5"
    if errorlevel 1 goto :failed
    echo   [ok ] abr adopted
    exit /b 0

    :failed
    echo   [ERROR] encode failed : %~n5
    exit /b 0
  BAT

  class << self
    def header
      HEADER.lines(chomp: true)
    end

    def footer
      FOOTER.lines(chomp: true)
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
