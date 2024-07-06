#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'example'

class HelloExample < Example
  def self.parse_opts(opts, param)
    opts.banner = 'Usage: hello_ex.rb [options]'

    param.x_value = Slithernix::Cdk::CENTER
    param.y_value = Slithernix::Cdk::CENTER
    param.box = true
    param.shadow = true
    super
  end

  # This program demonstrates the Cdk label widget.
  def self.main
    # Declare variables.
    params = parse(ARGV)

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.initCDKColor

    # Set the labels up.
    mesg = [
      '</5><#UL><#HL(30)><#UR>',
      '</5><#VL(10)>Hello World!<#VL(10)>',
      '</5><#LL><#HL(30)><#LR)'
    ]

    # Declare the labels.
    demo = Slithernix::Cdk::Widget::Label.new(cdkscreen,
                                              params.x_value, params.y_value, mesg, 3,
                                              params.box, params.shadow)

    # Is the label nll?
    if demo.nil?
      # Clean up the memory.
      cdkscreen.destroy

      # End curses...
      Slithernix::Cdk::Screen.endCDK

      puts 'Cannot create the label. Is the window too small?'
      exit #  EXIT_FAILURE
    end

    # Draw the CDK screen.
    cdkscreen.refresh
    demo.wait(' ')

    # Clean up
    demo.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    # ExitProgram (EXIT_SUCCESS);
  end
end

HelloExample.main
