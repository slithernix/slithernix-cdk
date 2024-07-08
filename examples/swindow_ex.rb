#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'example'

class SwindowExample < CLIExample
  def self.parse_opts(opts, params)
    opts.banner = 'Usage: swindow_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = Slithernix::Cdk::CENTER
    params.y_value = Slithernix::Cdk::CENTER
    params.h_value = 6
    params.w_value = 65

    super
  end

  # Demonstrate a scrolling-window.
  def self.main
    title = '<C></5>Error Log'

    # Declare variables.
    params = parse(ARGV)

    # Start curses
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Start CDK colors.
    Slithernix::Cdk::Draw.init_color

    # Create the scrolling window.
    swindow = Slithernix::Cdk::Widget::SWindow.new(
      cdkscreen,
      params.x_value,
      params.y_value,
      params.h_value,
      params.w_value,
      title,
      100,
      params.box,
      params.shadow,
    )

    # Is the window nil.
    if swindow.nil?
      # Exit CDK.
      cdkscreen.destroy
      Slithernix::Cdk::Screen.endCDK

      puts 'Cannot create the scrolling window. Is the window too small?'
      exit # EXIT_FAILURE
    end

    # Draw the scrolling window.
    swindow.draw(swindow.box)

    # Load up the scrolling window.
    swindow.add('<C></11>TOP: This is the first line.',
                Slithernix::Cdk::BOTTOM)
    swindow.add('<C>Sleeping for 1 second.', Slithernix::Cdk::BOTTOM)
    sleep(1)

    swindow.add('<L></11>1: This is another line.', Slithernix::Cdk::BOTTOM)
    swindow.add('<C>Sleeping for 1 second', Slithernix::Cdk::BOTTOM)
    sleep(1)

    swindow.add('<C></11>2: This is another line.', Slithernix::Cdk::BOTTOM)
    swindow.add('<C>Sleeping for 1 second.', Slithernix::Cdk::BOTTOM)
    sleep(1)

    swindow.add('<R></11>3: This is another line.', Slithernix::Cdk::BOTTOM)
    swindow.add('<C>Sleeping for 1 second', Slithernix::Cdk::BOTTOM)
    sleep(1)

    swindow.add('<C></11>4: This is another line.', Slithernix::Cdk::BOTTOM)
    swindow.add('<C>Sleeping for 1 second.', Slithernix::Cdk::BOTTOM)
    sleep(1)

    swindow.add('<L></11>5: This is another line.', Slithernix::Cdk::BOTTOM)
    swindow.add('<C>Sleeping for 1 second', Slithernix::Cdk::BOTTOM)
    sleep(1)

    swindow.add('<C></11>6: This is another line.', Slithernix::Cdk::BOTTOM)
    swindow.add('<C>Sleeping for 1 second.', Slithernix::Cdk::BOTTOM)
    sleep(1)

    swindow.add('<C>Done. You can now play.', Slithernix::Cdk::BOTTOM)

    swindow.add('<C>This is being added to the top.', Slithernix::Cdk::TOP)

    # Activate the scrolling window.
    swindow.activate([])

    # Check how the user exited this widget.
    if swindow.exit_type == :ESCAPE_HIT
      mesg = [
        '<C>You hit escape to leave this widget.',
        '',
        '<C>Press any key to continue.',
      ]
      cdkscreen.popup_label(mesg, 3)
    elsif swindow.exit_type == :NORMAL
      mesg = [
        '<C>You hit return to exit this widget.',
        '',
        '<C>Press any key to continue.'
      ]
      cdkscreen.popup_label(mesg, 3)
    end

    # Clean up.
    swindow.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    exit # EXIT_SUCCESS
  end
end

SwindowExample.main
