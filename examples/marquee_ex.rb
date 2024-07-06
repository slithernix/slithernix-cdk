#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'example'

class MarqueeExample < Example
  def self.parse_opts(opts, params)
    opts.banner = 'Usage: marquee_ex.rb [options]'

    # default values
    params.box = false
    params.shadow = true
    params.x_value = Slithernix::Cdk::CENTER
    params.y_value = Slithernix::Cdk::TOP

    params.message = String.new
    params.repeat_count = 3
    params.delay = 5
    params.bold = false
    params.reversed = false
    params.underline = false
    params.blinking = false
    params.width = 30

    params.start_attr = String.new
    params.end_attr = String.new

    super

    opts.on('-m TEXT', String, 'Sets the message to display in the marquee',
            'If no message is provided, one will be created.') do |text|
      params.message = text
    end

    opts.on('-R COUNT', OptionParser::DecimalInteger,
            'Repeat the message the given COUNT',
            'A of -1 repeats the message forever.') do |count|
      params.repeat_count = count
    end

    opts.on('-d COUNT', OptionParser::DecimalInteger,
            'number of milliseconds to delay between repeats.') do |count|
      params.delay = count
    end

    opts.on('-b', 'display the message with the bold attribute.') do
      params.bold = true
      params.start_attr << '/B'
      params.end_attr << '!B'
    end

    opts.on('-r', 'display the message with a reversed attribute.') do
      params.reversed = true
      params.start_attr << '/R'
      params.end_attr << '!R'
    end

    opts.on('-u', 'display the message with the underline attribute.') do
      params.underline = true
      params.start_attr << '/U'
      params.end_attr << '!U'
    end

    opts.on('-k', 'display the message with a blinking attribute.') do
      params.blinking = true
      params.start_attr << '/K'
      params.end_attr << '!K'
    end

    opts.on('-w WIDTH', OptionParser::DecimalInteger, 'Marquee width') do |w|
      params.width = w
    end
  end

  # This program demonstrates the Cdk marquee widget.
  def self.main
    # Declare variables.

    params = parse(ARGV)

    if params.start_attr.size.positive?
      params.start_attr = format('<%s>', params.start_attr)
      params.end_attr = format('<%s>', params.end_attr)
    end

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)
    Curses.curs_set(0)

    # Set up CDK colors
    Slithernix::Cdk::Draw.initCDKColor

    scroll_message = Slithernix::Cdk::Widget::Marquee.new(cdkscreen,
                                                          params.x_value, params.y_value, params.width,
                                                          params.box, params.shadow)

    # Check if the marquee is nil.
    if scroll_message.nil?
      # Exit Slithernix::Cdk.
      cdkscreen.destroy
      Slithernix::Cdk::Screen.endCDK

      puts 'Cannot create the marquee window.  Is the window too small?'
      exit # EXIT_FAILURE
    end

    # Draw the CDK screen.
    cdkscreen.refresh

    # Create the marquee message.
    if params.message == ''
      # Get the current time
      current_time = Time.new.ctime

      message = if params.start_attr.size.positive?
                  format('%s%s%s (This Space For Rent) ', params.start_attr,
                         current_time, params.end_attr)
                else
                  format('%s (This Space For Rent)', current_time)
                end
    elsif params.start_attr.size.positive?
      message = format('%s%s%s ', params.start_attr, mesg, params.end_attr)
    else
      message = format('%s ', params.message)
    end

    # Run the marquee.
    scroll_message.activate(message, params.delay, params.repeat_count, true)
    scroll_message.activate(message, params.delay, params.repeat_count, false)
    scroll_message.activate(message, params.delay, params.repeat_count, true)

    # Clean up.
    scroll_message.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    exit # EXIT_SUCCESS
  end
end

MarqueeExample.main
