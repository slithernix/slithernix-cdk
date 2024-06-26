#!/usr/bin/env ruby
require_relative 'example'

class MentryExample < Example
  def MentryExample.parse_opts(opts, param)
    opts.banner = 'Usage: mentry_ex.rb [options]'

    param.x_value = Cdk::CENTER
    param.y_value = Cdk::CENTER
    param.box = true
    param.shadow = false
    param.w = 20
    param.h = 5
    param.rows = 20

    super(opts, param)

    opts.on('-w WIDTH', OptionParser::DecimalInteger, 'Field width') do |w|
      param.w = w
    end

    opts.on('-h HEIGHT', OptionParser::DecimalInteger, 'Field height') do |h|
      param.h = h
    end

    opts.on('-l ROWS', OptionParser::DecimalInteger, 'Logical rows') do |rows|
      param.rows = rows
    end
  end

  # This demonstrates the positioning of a Cdk multiple-line entry
  # field widget.
  def MentryExample.main
    label = "</R>Message"
    title = "<C></5>Enter a message.<!5>"

    params = parse(ARGV)

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Cdk::Draw.initCDKColor

    widget = Cdk::MENTRY.new(cdkscreen, params.x_value, params.y_value,
                             title, label, Curses::A_BOLD, '.', :MIXED, params.w, params.h,
                             params.rows, 0, params.box, params.shadow)

    # Is the widget nil?
    if widget.nil?
      # Clean up.
      cdkscreen.destroy
      Cdk::Screen.endCDK

      puts "Cannot create CDK object. Is the window too small?"
      exit  # EXIT_FAILURE
    end

    # Draw the CDK screen.
    cdkscreen.refresh

    # Set whatever was given from the command line.
    arg = if ARGV.size > 0 then ARGV[0] else '' end
    widget.set(arg, 0, true)

    # Activate the entry field.
    widget.activate('')
    info = widget.info.clone

    # Clean up.
    widget.destroy
    cdkscreen.destroy
    Cdk::Screen.endCDK

    puts "\n\n"
    puts "Your message was : <%s>" % [info]
    #ExitProgram (EXIT_SUCCESS);
  end
end

MentryExample.main
