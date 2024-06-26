#!/usr/bin/env ruby
require_relative 'example'

class SubwindowExample < CLIExample
  def SubwindowExample.parse_opts(opts, params)
    opts.banner = 'Usage: subwindow_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = Slithernix::Cdk::CENTER
    params.y_value = Slithernix::Cdk::CENTER
    params.h_value = 10
    params.w_value = 15
    params.spos = Slithernix::Cdk::RIGHT

    super(opts, params)

    opts.on('-s SCROLL_POS', OptionParser::DecimalInteger,
        'location for the scrollbar') do |spos|
      params.spos = spos
    end
  end

  # This demo displays the ability to put widget within a curses subwindow.
  def SubwindowExample.main
    dow = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
        'Saturday', 'Sunday'
    ]

    # Declare variables.
    params = parse(ARGV)

    # Start curses
    curses_win = Curses.init_screen
    Curses.curs_set(0)

    # Create a basic window.
    sub_window = Curses::Window.new(
        Curses.lines - 5, Curses.lines - 10, 2, 5)

    # Start Slithernix::Cdk.
    cdkscreen = Slithernix::Cdk::Screen.new(sub_window)

    # Box our window.
    sub_window.box(Slithernix::Cdk::ACS_VLINE, Slithernix::Cdk::ACS_HLINE)
    sub_window.refresh

    # Create a basic scrolling list inside the window.
    dow_list = Slithernix::Cdk::Widget::Scroll.new(cdkscreen,
                               params.x_value, params.y_value, params.spos,
                               params.h_value, params.w_value, "<C></U>Pick a Day",
                               dow, 7, false, Curses::A_REVERSE, params.box, params.shadow)

    # Put a title within the window.
    mesg = [
        "<C><#HL(30)>",
        "<C>This is a Cdk scrolling list",
        "<C>inside a curses window.",
        "<C><#HL(30)>"
    ]
    title = Slithernix::Cdk::Widget::Label.new(cdkscreen, Slithernix::Cdk::CENTER, 0, mesg, 4, false, false)

    # Refresh the screen.
    cdkscreen.refresh

    # Let the user play.
    pick = dow_list.activate('')

    # Clean up.
    dow_list.destroy
    title.destroy
    Slithernix::Cdk.eraseCursesWindow(sub_window)
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK

    # Tell them what they picked.
    puts "You picked %s" % [dow[pick]]
    exit # EXIT_SUCCESS
  end
end

SubwindowExample.main
