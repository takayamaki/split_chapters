# frozen_string_literal: true

require_relative './ffprove'

class Video
  class Chapter
    attr_reader :start_at, :end_at, :time_base

    def initialize(start_at:, end_at:, time_base:)
      @start_at = start_at
      @end_at = end_at
      @time_base = time_base.to_r
    end

    def to_range
      start_at...end_at
    end

    def duration = (end_at - start_at) * time_base
    def start_at_integer_part = (start_at / time_base.denominator).to_i
    def end_at_integer_part = (end_at / time_base.denominator).to_i
    def start_at_fractional_part = (start_at % time_base.denominator) * time_base
    def end_at_fractional_part = (end_at % time_base.denominator) * time_base
  end

  attr_reader :chapters, :file_path

  def initialize(file_path, chapters)
    @file_path = file_path
    @chapters = chapters.map do |chapter|
      Chapter.new(
        start_at: chapter[:start],
        end_at: chapter[:end],
        time_base: chapter[:time_base]
      )
    end
  end
end
