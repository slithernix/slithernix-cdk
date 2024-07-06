#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'example'

class Radio1Example < CLIExample
  def self.parse_opts(opts, params)
    opts.banner = 'Usage: radio1_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = Slithernix::Cdk::CENTER
    params.y_value = Slithernix::Cdk::CENTER
    params.h_value = 5
    params.w_value = 20
    params.spos = Slithernix::Cdk::NONE
    params.title = String.new

    super

    opts.on('-s SCROLL_POS', OptionParser::DecimalInteger,
            'location for the scrollbar') do |spos|
      params.spos = spos
    end

    opts.on('-t TITLE', String, 'title for the widget') do |title|
      params.title = title
    end
  end

  # This program demonstrates the Cdk radio widget.
  #
  # Options (in addition to normal CLI parameters):
  #   -s SPOS location for the scrollbar
  #   -t TEXT title for the widget
  def self.main
    params = parse(ARGV)

    # Use the current directory list to fill the radio list
    item = [
      'Choice A',
      'Choice B',
      'Choice C',
    ]

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.initCDKColor

    # Create the radio list.
    radio = Slithernix::Cdk::Widget::Radio.new(cdkscreen,
                                               params.x_value, params.y_value, params.spos,
                                               params.h_value, params.w_value, params.title,
                                               item, 3, '#'.ord | Curses::A_REVERSE, true,
                                               Curses::A_REVERSE, params.box, params.shadow)

    if radio.nil?
      cdkscreen.destroyCDKScreen
      Slithernix::Cdk::Screen.endCDK

      puts 'Cannot make radio widget.  Is the window too small?'
      exit # EXIT_FAILURE
    end

    # Activate the radio widget.
    selection = radio.activate([])

    # Check the exit status of the widget.
    if radio.exit_type == :ESCAPE_HIT
      mesg = [
        '<C>You hit escape. No item selected',
        '',
        '<C>Press any key to continue.'
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif radio.exit_type == :NORMAL
      mesg = [
        '<C> You selected the filename',
        format('<C>%.*s', 236, item[selection]), # FIXME: magic number
        '',
        '<C>Press any key to continue'
      ]
      cdkscreen.popupLabel(mesg, 4)
    end

    # Clean up.
    radio.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    exit # EXIT_SUCCESS
  end
end

Radio1Example.main
