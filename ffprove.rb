# frozen_string_literal: true
require 'json'

module FFProve
  def self.chapters(file_path, base_path: '/mnt/d/BDRipping/')
    ffprove_output = JSON.parse(`ffprobe #{file_path} -of json -show_chapters -loglevel quiet`,
                                symbolize_names: true)
    pp ffprove_output.dig(:chapters)
  end
end

FFProve.chapters('kansyasai2019_2020/kansyasai2019_2020.mkv')
