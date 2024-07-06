#!/usr/bin/env ruby
require_relative 'example'

class HistogramExample < CLIExample
  def self.parse_opts(opts, params)
    opts.banner = 'Usage: histogram_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = 10
    params.y_value = false
    params.y_vol = 10
    params.y_bass = 14
    params.y_treb = 18
    params.h_value = 1
    params.w_value = -2

    super

    return unless params.y_value != false

    params.y_vol = params.y_value
    params.y_bass = params.y_value
    params.y_treb = params.y_value
  end

  def self.main
    params = parse(ARGV)

    # Set up CDK
    cdkscreen = Slithernix::Cdk::Screen.new

    # Set up CDK colors
    Slithernix::Cdk::Draw.initCDKColor

    # Create the histogram widgets.
    volume_title = '<C></5>Volume<!5>'
    bass_title = '<C></5>Bass  <!5>'
    treble_title = '<C></5>Treble<!5>'
    box = params.box

    volume = Slithernix::Cdk::Widget::Histogram.new(cdkscreen, params.x_value, params.y_vol,
                                                    params.h_value, params.w_value, Slithernix::Cdk::HORIZONTAL, volume_title,
                                                    box, params.shadow)

    # Is the volume null?
    if volume.nil?
      cdkscreen.destroy
      Slithernix::Cdk::Screen.endCDK

      puts 'Cannot make volume histogram.  Is the window big enough?'
      exit # EXIT_FAILURE
    end

    bass = Slithernix::Cdk::Widget::Histogram.new(cdkscreen, params.x_value, params.y_bass,
                                                  params.h_value, params.w_value, Slithernix::Cdk::HORIZONTAL, bass_title,
                                                  box, params.shadow)

    if bass.nil?
      volume.destroy
      cdkscreen.destroy
      Slithernix::Cdk::Screen.endCDK

      puts 'Cannot make bass histogram.  Is the window big enough?'
      exit  # EXIT_FAILURE
    end

    treble = Slithernix::Cdk::Widget::Histogram.new(cdkscreen, params.x_value, params.y_treb,
                                                    params.h_value, params.w_value, Slithernix::Cdk::HORIZONTAL, treble_title,
                                                    box, params.shadow)

    if treble.nil?
      volume.destroy
      bass.destroy
      cdkscreen.destroy
      Slithernix::Cdk::Screen.endCDK

      puts 'Cannot make treble histogram.  Is the window big enough?'
      exit  # EXIT_FAILURE
    end

    # Set the histogram values.
    volume.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 6,
               ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    bass.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 3,
             ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    treble.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 7,
               ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    cdkscreen.refresh
    sleep(4)

    # Set the histogram values.
    volume.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 8,
               ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    bass.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 1,
             ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    treble.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 9,
               ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    cdkscreen.refresh
    sleep(4)

    # Set the histogram values.
    volume.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 10,
               ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    bass.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 7,
             ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    treble.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 10,
               ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    cdkscreen.refresh
    sleep(4)

    # Set the histogram values.
    volume.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 1,
               ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    bass.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 8,
             ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    treble.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 3,
               ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    cdkscreen.refresh
    sleep(4)

    # Set the histogram values.
    volume.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 3,
               ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    bass.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 3,
             ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    treble.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 3,
               ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    cdkscreen.refresh
    sleep(4)

    # Set the histogram values.
    volume.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 10,
               ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    bass.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 10,
             ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    treble.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 10,
               ' '.ord | Curses::A_REVERSE | Curses.color_pair(3), box)
    cdkscreen.refresh
    sleep(4)

    # Clean up
    volume.destroy
    bass.destroy
    treble.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    exit # EXIT_SUCCESS
  end
end

HistogramExample.main
