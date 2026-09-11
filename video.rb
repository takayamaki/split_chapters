# frozen_string_literal: true

require_relative 'ffprove'

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

  def initialize(file_path, chapters, r_frame_rate: nil, avg_frame_rate: nil)
    @file_path = file_path
    @r_frame_rate = r_frame_rate
    @avg_frame_rate = avg_frame_rate
    @chapters = chapters.map do |chapter|
      Chapter.new(
        start_at: chapter[:start],
        end_at: chapter[:end],
        time_base: chapter[:time_base]
      )
    end
  end

  # candidates for normalizing a VFR source, as "num/den" strings ffmpeg -r accepts
  STANDARD_FRAME_RATES = %w[24000/1001 24/1 25/1 30000/1001 30/1 50/1 60000/1001 60/1].freeze

  # "num/den" string to pass to ffmpeg -r. CFR sources (r == avg within 1%)
  # keep their own rate; VFR sources snap to the standard rate nearest to avg.
  def frame_rate
    r = to_rational(@r_frame_rate)
    avg = to_rational(@avg_frame_rate)
    return @r_frame_rate if r.nil? || avg.nil? || (r - avg).abs <= r / 100

    STANDARD_FRAME_RATES.min_by { |candidate| (Rational(candidate) - avg).abs }
  end

  private

  def to_rational(fraction)
    value = Rational(fraction)
    value.positive? ? value : nil
  rescue ZeroDivisionError, ArgumentError, TypeError
    nil
  end
end
