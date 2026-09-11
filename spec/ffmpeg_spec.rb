# frozen_string_literal: true

require_relative '../ffmpeg'
require_relative '../video'

RSpec.describe FFMpeg do
  describe '.output_commands' do
    context '60〜600秒のチャプターが1つある動画' do
      let(:video) { Video.new('/mnt/d/video.mkv', [{ start: 0, end: 180_000, time_base: '1/1000' }]) }

      it ':encode サブルーチンを call する行を1行返す' do
        lines = described_class.output_commands(video)
        expect(lines.length).to eq 1
        expect(lines.first).to start_with('call :encode ')
      end
      it 'ソースの Windows パス・シーク整数部・シーク小数部・長さ・出力パス・stats ファイル名を引数に渡す' do
        expect(described_class.output_commands(video).first)
          .to eq 'call :encode "D:\\video.mkv" 0 0.0 180.0 "D:\\video_1.mp4" "video.log"'
      end
    end

    context 'チャプターが複数ある動画' do
      let(:video) do
        chapters = Array.new(10) { |i| { start: i * 100_000, end: (i + 1) * 100_000, time_base: '1/1000' } }
        Video.new('/mnt/d/video.mkv', chapters)
      end

      it 'チャプター数の桁数で連番をゼロ埋めした出力ファイル名を渡す' do
        lines = described_class.output_commands(video)
        expect(lines.length).to eq 10
        expect(lines[0]).to include '"D:\\video_01.mp4"'
        expect(lines[9]).to eq 'call :encode "D:\\video.mkv" 900 0.0 100.0 "D:\\video_10.mp4" "video.log"'
      end
    end

    context '60秒未満または600秒超のチャプターを含む動画' do
      let(:video) do
        Video.new('/mnt/d/video.mkv', [
                    { start: 0, end: 5_000, time_base: '1/1000' },
                    { start: 5_000, end: 185_500, time_base: '1/1000' },
                    { start: 185_500, end: 900_000, time_base: '1/1000' }
                  ])
      end

      it 'そのチャプターの call 行だけ @rem でコメントアウトする' do
        lines = described_class.output_commands(video)
        expect(lines[0]).to start_with '@rem call :encode '
        expect(lines[1]).to eq 'call :encode "D:\\video.mkv" 5 0.0 180.5 "D:\\video_2.mp4" "video.log"'
        expect(lines[2]).to start_with '@rem call :encode '
      end
    end
  end

  describe '.header' do
    it 'echo を切って bat 自身のディレクトリに移動する'
    it 'CRF / LIMIT / ABRBV / CRFCAP / PROBETHR を set する'
  end

  describe '.footer' do
    it 'call 行の後に実行されないよう exit /b で区切ってから :encode を定義する'

    context 'pass 1 の probe' do
      it 'crf の pass 1 を -loglevel info で走らせ stderr をファイルに落とす'
      it 'x264 の kb/s: 行から整数 kbps を取り出す'
    end

    context 'probe が PROBETHR 以下のとき' do
      it 'crf 単発でエンコードし、ffprobe の bit_rate が LIMIT 以下なら採用する'
    end

    context 'probe が PROBETHR を超えたとき' do
      it 'crf を飛ばして同じ stats で pass 2 abr を走らせる'
    end

    context 'crf の結果が LIMIT を超えたとき' do
      it 'pass 2 abr にフォールバックする'
    end
  end
end
