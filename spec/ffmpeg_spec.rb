# frozen_string_literal: true

require_relative '../ffmpeg'
require_relative '../video'

RSpec.describe FFMpeg do
  describe '.output_commands' do
    context '60〜600秒のチャプターが1つある動画' do
      let(:video) { Video.new('/mnt/d/video.mkv', [{ start: 0, end: 180_000, time_base: '1/1000' }], r_frame_rate: '24/1', avg_frame_rate: '24/1') }

      it ':encode サブルーチンを call する行を1行返す' do
        lines = described_class.output_commands(video)
        expect(lines.length).to eq 1
        expect(lines.first).to start_with('call :encode ')
      end
      it 'CFR 化に使うフレームレートを最後の引数で渡す' do
        expect(described_class.output_commands(video).first).to end_with ' "video.log" 24/1'
      end

      it 'ソースの Windows パス・シーク整数部・シーク小数部・長さ・出力パス・stats ファイル名を引数に渡す' do
        expect(described_class.output_commands(video).first)
          .to eq 'call :encode "D:\\video.mkv" 0 0.0 180.0 "D:\\video_1.mp4" "video.log" 24/1'
      end
    end

    context 'チャプターが複数ある動画' do
      let(:video) do
        chapters = Array.new(10) { |i| { start: i * 100_000, end: (i + 1) * 100_000, time_base: '1/1000' } }
        Video.new('/mnt/d/video.mkv', chapters, r_frame_rate: '30000/1001', avg_frame_rate: '30000/1001')
      end

      it 'チャプター数の桁数で連番をゼロ埋めした出力ファイル名を渡す' do
        lines = described_class.output_commands(video)
        expect(lines.length).to eq 10
        expect(lines[0]).to include '"D:\\video_01.mp4"'
        expect(lines[9]).to eq 'call :encode "D:\\video.mkv" 900 0.0 100.0 "D:\\video_10.mp4" "video.log" 30000/1001'
      end
    end

    context '60秒未満または600秒超のチャプターを含む動画' do
      let(:video) do
        Video.new('/mnt/d/video.mkv', [
                    { start: 0, end: 5_000, time_base: '1/1000' },
                    { start: 5_000, end: 185_500, time_base: '1/1000' },
                    { start: 185_500, end: 900_000, time_base: '1/1000' }
                  ], r_frame_rate: '24/1', avg_frame_rate: '24/1')
      end

      it 'そのチャプターの call 行だけ @rem でコメントアウトする' do
        lines = described_class.output_commands(video)
        expect(lines[0]).to start_with '@rem call :encode '
        expect(lines[1]).to eq 'call :encode "D:\\video.mkv" 5 0.0 180.5 "D:\\video_2.mp4" "video.log" 24/1'
        expect(lines[2]).to start_with '@rem call :encode '
      end
    end
  end

  describe '.remove_2pass_log_commands' do
    it 'stats ファイルと mbtree を、存在するときだけ削除する' do
      expect(described_class.remove_2pass_log_commands('/mnt/d/video.mkv')).to eq [
        'if exist "video.log" del "video.log"',
        'if exist "video.log.mbtree" del "video.log.mbtree"'
      ]
    end
  end

  describe '.convert_to_win_path' do
    context 'WSL 標準の /mnt/<drive>/ 配下のパス' do
      it 'ドライブレターと \\ 区切りの Windows パスに変換する' do
        expect(described_class.convert_to_win_path('/mnt/d/BDRipping/video.mkv')).to eq 'D:\\BDRipping\\video.mkv'
      end
    end

    context 'devcontainer で /mnt/windows/<drive>/ にマウントされたパス' do
      it '同じく Windows パスに変換する' do
        expect(described_class.convert_to_win_path('/mnt/windows/d/BDRipping/video.mkv')).to eq 'D:\\BDRipping\\video.mkv'
      end
    end

    context 'WSL ホスト側から見た devcontainer の bind mount (<workspace>/.devcontainer/mnt/windows/<drive>/) 配下のパス' do
      it 'mnt/windows/<drive>/ より前を捨てて Windows パスに変換する' do
        expect(described_class.convert_to_win_path('/home/user/ws/.devcontainer/mnt/windows/d/BDRipping/video.mkv'))
          .to eq 'D:\\BDRipping\\video.mkv'
      end
    end
  end

  describe '.header' do
    subject(:header) { described_class.header }

    it 'echo を切って bat 自身のディレクトリに移動する' do
      expect(header.first(3)).to eq ['@echo off', 'setlocal', 'cd /d %~dp0']
    end

    it 'VBASE (1秒ごとの I フレーム, High profile) と X264OPT (ref=4, bframes=2, b-pyramid none, level 5.1) を set する' do
      expect(header).to include(
        'set "X264OPT=ref=4:bframes=2:b-pyramid=none:level=5.1"',
        'set "VBASE=-vcodec libx264 -preset veryslow -profile:v high -pix_fmt yuv420p -force_key_frames "expr:gte(t,n_forced)""'
      )
    end

    it 'CRF / LIMIT / ABRBV / CRFCAP / PROBETHR を set する' do
      expect(header).to include(
        'set "CRF=18"',
        'set "LIMIT=8320"',
        'set "ABRBV=8192k"',
        'set "CRFCAP=-maxrate 20000k -bufsize 40000k"',
        'set "PROBETHR=7800"',
        'set /a LIMITBPS=%LIMIT%*1000'
      )
    end
  end

  describe '.footer' do
    subject(:footer) { described_class.footer }

    it 'call 行の後に実行されないよう exit /b で区切ってから :encode を定義する' do
      expect(footer.first).to eq 'exit /b 0'
      expect(footer).to include ':encode'
    end

    context 'エンコードオプション' do
      let(:commands) { footer.grep(/^bin\\ffmpeg\.exe /) }

      it 'pass 1 / crf / pass 2 の3コマンドすべてで -fps_mode cfr -r %7 と %VBASE% を使う' do
        expect(commands.length).to eq 3
        commands.each do |command|
          expect(command).to include '-ss %2 -i "%~1" -ss %3 -t %4 -fps_mode cfr -r %7 %VBASE% '
        end
      end

      it 'pass 1 と pass 2 は stats と X264OPT を同じ -x264-params に入れ、crf は X264OPT だけ渡す' do
        pass1, crf, pass2 = commands
        expect(pass1).to include '-x264-params "stats=%~6:%X264OPT%" -pass 1'
        expect(crf).to include '-x264-params "%X264OPT%" -movflags +faststart'
        expect(pass2).to include '-x264-params "stats=%~6:%X264OPT%" -pass 2'
      end
    end

    context 'pass 1 の probe' do
      it 'crf の pass 1 を -loglevel info で走らせ stderr をファイルに落とす' do
        pass1 = footer.find { |line| line.include?('-pass 1') }
        expect(pass1).to start_with 'bin\\ffmpeg.exe -y -hide_banner -loglevel info -nostats -ss %2 -i "%~1" -ss %3 -t %4 '
        expect(pass1).to include '%VBASE% -crf %CRF% %CRFCAP% -an -map 0:v:0'
        expect(pass1).to end_with '-x264-params "stats=%~6:%X264OPT%" -pass 1 -f null nul 2> "%PROBE%"'
      end

      it 'x264 の kb/s: 行から整数 kbps を取り出す' do
        expect(footer).to include(
          %q(for /f "tokens=2 delims=:" %%k in ('findstr /c:"kb/s:" "%PROBE%"') do set "P1K=%%k"),
          'for /f "tokens=1 delims=. " %%k in ("%P1K%") do set "P1K=%%k"',
          'if not defined P1K goto :abrpass2'
        )
      end
    end

    context 'probe が PROBETHR 以下のとき' do
      it 'crf 単発でエンコードし、ffprobe の bit_rate が LIMIT 以下なら採用する' do
        expect(footer).to include('if %P1K% LEQ %PROBETHR% goto :crfpass', ':crfpass')
        crf = footer.find { |line| line.include?('-crf %CRF%') && line.include?('-movflags +faststart') }
        expect(crf).to include '-loglevel error -stats -ss %2 -i "%~1" -ss %3 -t %4 -fps_mode cfr -r %7 %VBASE% -crf %CRF% %CRFCAP% -acodec aac -b:a 128k -map 0:v:0 -map 0:a:0'
        expect(crf).to end_with '-movflags +faststart "%~5"'
        expect(crf).not_to include '-pass'
        expect(footer).to include(
          'bin\\ffprobe.exe -v error -show_entries format=bit_rate -of default=nw=1:nk=1 "%~5" > "%PROBE%" 2>nul',
          'echo   [ok ] %BRK% kbps ^<= %LIMIT% kbps  -^> adopt crf'
        )
      end
    end

    context 'probe が PROBETHR を超えたとき' do
      it 'crf を飛ばして同じ stats で pass 2 abr を走らせる' do
        leq = footer.index('if %P1K% LEQ %PROBETHR% goto :crfpass')
        expect(footer[leq + 2]).to eq 'goto :abrpass2'
        expect(footer).to include ':abrpass2'
        pass2 = footer.find { |line| line.include?('-pass 2') }
        expect(pass2).to include '%VBASE% -b:v %ABRBV% -acodec aac -b:a 128k -map 0:v:0 -map 0:a:0'
        expect(pass2).to end_with '-x264-params "stats=%~6:%X264OPT%" -pass 2 -movflags +faststart "%~5"'
        expect(footer).not_to include(a_string_matching(/-b:v %ABRBV%.*-pass 1/))
      end
    end

    context 'ffmpeg が失敗したとき' do
      it 'ffmpeg 6.1 以降が返す負の終了コードも拾って :failed に飛ぶ' do
        expect(footer).not_to include 'if errorlevel 1 goto :failed'
        expect(footer.count('if %errorlevel% neq 0 goto :failed')).to eq 3
        expect(footer).to include ':failed'
      end
    end

    context 'crf の結果が LIMIT を超えたとき' do
      it 'pass 2 abr にフォールバックする' do
        expect(footer).to include(
          'if %BR% GTR %LIMITBPS% goto :abrpass2',
          'if defined BRK echo   [--] %BRK% kbps ^> %LIMIT% kbps  -^> fall back to 2-pass abr'
        )
      end
    end
  end
end
