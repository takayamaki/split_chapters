# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe 'split_chapters.rb' do
  def run(*args)
    Open3.capture3('ruby', File.expand_path('../split_chapters.rb', __dir__), *args)
  end

  # a 2-second test clip with two chapters, generated with ffmpeg
  def make_chaptered_clip(dir, name)
    meta = File.join(dir, "#{name}.txt")
    File.write(meta, ";FFMETADATA1\n[CHAPTER]\nTIMEBASE=1/1000\nSTART=0\nEND=1000\ntitle=a\n[CHAPTER]\nTIMEBASE=1/1000\nSTART=1000\nEND=2000\ntitle=b\n")
    path = File.join(dir, "#{name}.mkv")
    system('ffmpeg', '-y', '-loglevel', 'error', '-f', 'lavfi', '-i', 'color=c=black:s=64x64:r=24', '-i', meta,
           '-map_metadata', '1', '-t', '2', '-c:v', 'libx264', '-preset', 'ultrafast', path, exception: true)
    path
  end

  context '存在する動画を複数渡したとき' do
    it 'それぞれのチャプターの call 行を1つの bat にまとめて出力する' do
      Dir.mktmpdir do |dir|
        a = make_chaptered_clip(dir, 'a')
        b = make_chaptered_clip(dir, 'b')
        out, err, status = run(a, b)
        expect(status.exitstatus).to eq(0), err
        calls = out.lines.grep(/call :encode /)
        expect(calls.length).to eq 4
        expect(calls.count { |l| l.include?('a_1.mp4') }).to eq 1
        expect(calls.count { |l| l.include?('b_2.mp4') }).to eq 1
        expect(out.scan(/^:encode\r?$/).length).to eq 1
      end
    end
  end

  context '--min-duration 0 を渡したとき' do
    it '60秒未満のチャプターも @rem なしで出す（テストクリップは 1 秒チャプター）' do
      Dir.mktmpdir do |dir|
        a = make_chaptered_clip(dir, 'a')
        out, err, status = run('--min-duration', '0', a)
        expect(status.exitstatus).to eq(0), err
        expect(out.lines.grep(/^call :encode /).length).to eq 2
        expect(out.lines.grep(/^@rem call :encode /)).to be_empty
      end
    end
  end

  context '引数なしで実行したとき' do
    it '標準エラーに usage を出して終了コード 1 で終わる' do
      out, err, status = run
      expect(status.exitstatus).to eq 1
      expect(out).to be_empty
      expect(err).to start_with 'Usage: split_chapters [OPTION]... FILE...'
    end
  end

  context '-h / --help を渡したとき' do
    it '標準出力に usage を出して終了コード 0 で終わる' do
      %w[-h --help].each do |flag|
        out, err, status = run(flag)
        expect(status.exitstatus).to eq 0
        expect(err).to be_empty
        expect(out).to start_with 'Usage: split_chapters [OPTION]... FILE...'
        expect(out).to include '-h, --help'
      end
    end
  end

  context '存在しないファイルを渡したとき' do
    it 'coreutils 風のエラーメッセージを標準エラーに出して終了コード 1 で終わる' do
      out, err, status = run('/nonexistent/video.mkv')
      expect(status.exitstatus).to eq 1
      expect(out).to be_empty
      expect(err).to eq "split_chapters: cannot access '/nonexistent/video.mkv': No such file or directory\n"
    end
  end
end
