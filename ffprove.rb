# frozen_string_literal: true
require_relative './chapter'
require 'json'

module FFProve
  def self.chapters(file_path, base_path: '/mnt/d/BDRipping/')
    ffprove_output = JSON.parse(`ffprobe #{file_path} -of json -show_chapters -loglevel quiet`,
                                symbolize_names: true)
    ffprove_output[:chapters].map do |chapter|
      Chapter.new(
        start_at: chapter[:start],
        end_at: chapter[:end],
        time_base: chapter[:time_base],
      )
    end
  end
end

FFProve.chapters('kansyasai2019_2020/kansyasai2019_2020.mkv')
