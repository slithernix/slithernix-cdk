#!/usr/bin/env ruby
require_relative 'example'

class SliderExample < Example
  def SliderExample.parse_opts(opts, param)
    opts.banner = 'Usage: slider_ex.rb [options]'

    param.x_value = Cdk::CENTER
    param.y_value = Cdk::CENTER
    param.box = true
    param.shadow = false
    param.high = 100
    param.low = 1
    param.inc = 1
    param.width = 50
    super(opts, param)

    opts.on('-h HIGH', OptionParser::DecimalInteger, 'High value') do |h|
      param.high = h
    end

    opts.on('-l LOW', OptionParser::DecimalInteger, 'Low value') do |l|
      param.low = l
    end

    opts.on('-i INC', OptionParser::DecimalInteger, 'Increment amount') do |i|
      param.inc = i
    end

    opts.on('-w WIDTH', OptionParser::DecimalInteger, 'Widget width') do |w|
      param.width = w
    end
  end

  # This program demonstrates the Cdk slider widget.
  def SliderExample.main
    # Declare variables.
    title = '<C></U>Enter a value'
    label = '</B>Current Value:'
    params = parse(ARGV)

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Cdk::Draw.initCDKColor

    # Create the widget
    widget = Cdk::SLIDER.new(cdkscreen, params.x_value, params.y_value,
                             title, label,
                             Curses::A_REVERSE | Curses.color_pair(29) | ' '.ord,
                             params.width, params.low, params.low, params.high, params.inc,
                             (params.inc * 2), params.box, params.shadow)

    # Is the widget nll?
    if widget.nil?
      # Exit CDK.
      cdkscreen.destroy
      Cdk::Screen.endCDK

      puts "Cannot make the widget. Is the window too small?"
      exit  # EXIT_FAILURE
    end

    # Activate the widget.
    selection = widget.activate([])

    # Check the exit value of the widget.
    if widget.exit_type == :ESCAPE_HIT
      mesg = [
          '<C>You hit escape. No value selected.',
          '',
          '<C>Press any key to continue.',
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif widget.exit_type == :NORMAL
      mesg = [
          '<C>You selected %d' % selection,
          '',
          '<C>Press any key to continue.',
      ]
      cdkscreen.popupLabel(mesg, 3)
    end

    # Clean up
    widget.destroy
    cdkscreen.destroy
    Cdk::Screen.endCDK
    #ExitProgram (EXIT_SUCCESS);
  end
end

SliderExample.main
