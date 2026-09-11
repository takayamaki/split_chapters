# frozen_string_literal: true

require 'open3'

RSpec.describe 'split_chapters.rb' do
  def run(*args)
    Open3.capture3('ruby', File.expand_path('../split_chapters.rb', __dir__), *args)
  end

  context '存在する動画を複数渡したとき' do
    it 'それぞれのチャプターの call 行を1つの bat にまとめて出力する'
  end

  context '引数なしで実行したとき' do
    it '標準エラーに usage を出して終了コード 1 で終わる'
  end

  context '-h / --help を渡したとき' do
    it '標準出力に usage を出して終了コード 0 で終わる'
  end

  context '存在しないファイルを渡したとき' do
    it 'coreutils 風のエラーメッセージを標準エラーに出して終了コード 1 で終わる'
  end
end
