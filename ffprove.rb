# frozen_string_literal: true

require 'json'

module FFProve
  def self.chapters(file_path)
    ffprove_output = JSON.parse(`ffprobe '#{file_path}' -of json -show_chapters -loglevel quiet`,
                                symbolize_names: true)
    ffprove_output[:chapters]
  end

  # => { r_frame_rate: "30000/1001", avg_frame_rate: "30000/1001" } of the first video stream
  def self.frame_rates(file_path)
    ffprove_output = JSON.parse(
      `ffprobe '#{file_path}' -of json -select_streams v:0 -show_entries stream=r_frame_rate,avg_frame_rate -loglevel quiet`,
      symbolize_names: true
    )
    ffprove_output[:streams].first.slice(:r_frame_rate, :avg_frame_rate)
  end
end
