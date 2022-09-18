# frozen_string_literal: true

class Chapter
  attr_reader :start_at, :end_at

  def initialize(start_at:, end_at:, time_base:)
    @start_at = start_at
    @end_at = end_at
    @time_base = time_base.to_r
  end

  def to_range
    start_at...end_at
  end

  def start_at_integer_part = (start_at/time_base.denominator).to_i
  def end_at_integer_part = (end_at/time_base.denominator).to_i
  def start_at_fractional_part = (start_at%time_base.denominator)*time_base
  def end_at_fractional_part = (end_at%time_base.denominator)*time_base
end
