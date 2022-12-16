# frozen_string_literal: true
require_relative './video'
require 'json'

module FFProve
  def self.chapters(file_path)
    ffprove_output = JSON.parse(`ffprobe #{file_path} -of json -show_chapters -loglevel quiet`,
                                symbolize_names: true)
    ffprove_output[:chapters]
  end
end
