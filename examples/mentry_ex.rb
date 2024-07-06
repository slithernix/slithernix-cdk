#!/usr/bin/env ruby
require_relative 'example'

class MentryExample < Example
  def self.parse_opts(opts, param)
    opts.banner = 'Usage: mentry_ex.rb [options]'

    param.x_value = Slithernix::Cdk::CENTER
    param.y_value = Slithernix::Cdk::CENTER
    param.box = true
    param.shadow = false
    param.w = 20
    param.h = 5
    param.rows = 20

    super

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
  def self.main
    label = '</R>Message'
    title = '<C></5>Enter a message.<!5>'

    params = parse(ARGV)

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.initCDKColor

    widget = Slithernix::Cdk::Widget::MEntry.new(cdkscreen, params.x_value, params.y_value,
                                                 title, label, Curses::A_BOLD, '.', :MIXED, params.w, params.h,
                                                 params.rows, 0, params.box, params.shadow)

    # Is the widget nil?
    if widget.nil?
      # Clean up.
      cdkscreen.destroy
      Slithernix::Cdk::Screen.endCDK

      puts 'Cannot create CDK widget. Is the window too small?'
      exit
    end

    # Draw the CDK screen.
    cdkscreen.refresh

    # Set whatever was given from the command line.
    arg = ARGV.size.positive? ? ARGV[0] : ''
    widget.set(arg, 0, true)

    # Activate the entry field.
    widget.activate('')
    info = widget.info.clone

    # Clean up.
    widget.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK

    puts "\n\n"
    puts format('Your message was : <%s>', info)
    # ExitProgram (EXIT_SUCCESS);
  end
end

MentryExample.main
