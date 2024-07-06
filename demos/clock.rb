#!/usr/bin/env ruby
require 'optparse'
require_relative '../lib/slithernix/cdk'

class Clock
  def self.main
    box_label = OptionParser.getopts('b')['b']

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.initCDKColor

    # Set the labels up.
    mesg = [
      '</1/B>HH:MM:SS',
    ]

    # Declare the labels.
    demo = Slithernix::Cdk::Widget::Label.new(
      cdkscreen,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::CENTER,
      mesg,
      1,
      box_label,
      false,
    )

    # Is the label nil?
    if demo.nil?
      # Clean up the memory.
      cdkscreen.destroy

      # End curses...
      Slithernix::Cdk.endCDK

      puts 'Cannot create the label. Is the window too small?'
      exit # EXIT_FAILURE
    end

    Curses.curs_set(0)
    demo.screen.window.timeout = 50

    # Do this for a while
    loop do
      # Get the current time.
      current_time = Time.now.getlocal

      # Put the current time in a string.
      mesg = [
        format('<C></B/29>%02d:%02d:%02d', current_time.hour,
               current_time.min, current_time.sec)
      ]

      # Set the label contents
      demo.set(mesg, 1, demo.box)

      # Draw the label and sleep
      demo.draw(demo.box)
      Curses.napms(10)

      # Break the loop if q is pressed
      break if demo.screen.window.getch == 'q'
    end

    # Clean up
    demo.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    # ExitProgram (EXIT_SUCCESS);
  end
end

Clock.main
