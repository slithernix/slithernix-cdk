# frozen_string_literal: true
require 'pry-remote'

class Integer
  def clear_bits(mask)
    self & ~mask
    self
  end

  def keep_bits(mask)
    self & mask
    self
  end
end

# I hate this but, whatever
module Curses
#  MAGIC_COLOR_PAIR_INDEX = 42.freeze
#
#  @color_pairs = [ ]
#  @max_color_pairs = 0
#
#  class << self
#    alias_method :original_init_pair, :init_pair
#    alias_method :original_color_pair, :color_pair
#    alias_method :original_pair_content, :pair_content
#    alias_method :original_pair_number, :pair_number
#  end
#
#  def self.ruby_color_pair_verify(cp)
#    raise StandardError, "colors aren't available!" unless Curses.has_colors?
#
#    if @max_color_pairs != (Curses.colors ** 2)
#      @max_color_pairs = Curses.colors ** 2
#    end
#
#    unless cp <= @max_color_pairs
#      raise ArgumentError, "Invalid pair number #{cp}/#{@max_color_pairs}"
#    end
#  end
#
#  def self.color_pair(cp)
#    ruby_color_pair_verify cp
#    fg, bg = pair_content(cp)
#    original_init_pair(
#      MAGIC_COLOR_PAIR_INDEX,
#      fg,
#      bg,
#    )
#    original_color_pair(MAGIC_COLOR_PAIR_INDEX)
#  end
#
#  def self.init_pair(cp, fg, bg)
#    true
#  end
#
  def self.napms(ms)
    sleep(ms / 1000.0)
  end

  def self.pair_content(cp)
    [ cp / Curses.colors, cp % Curses.colors ]
  end

  def self.pair_number(attr)
    attr
  end

  def self.unctrl(ch)
    raise Curses::Error, 'Input is not an Integer' unless ch.is_a?(Integer)

    if ch.negative? || ch > 127
      raise Curses::Error, 'Input is out of ASCII range'
    end

    if (32..126).include?(ch)
      ch.chr
    elsif ch == 127
      '^?'
    else
      "^#{(ch + 64).chr}"
    end
  rescue StandardError => e
    raise Curses::Error, "Error in unctrl: #{e.message}"
  end

  class Window
    def mvwvline(y, x, ch, n)
      n.times do |i|
        setpos(y + i, x)
        addch(ch)
      end
    end

    def mvwhline(y, x, ch, n)
      setpos(y, x)

      n.times do |_i|
        addch(ch)
      end
    end

    def mvwaddch(y, x, ch)
      setpos(y, x)
      addch(ch)
    end

    def mvwdelch(y, x)
      setpos(y, x)
      delch
    end

    def mvwinsch(y, x, ch)
      setpos(y, x)
      insch(ch)
    end

    def mvinch(y, x)
      setpos(y, x)
      inch
    end
  end
end
