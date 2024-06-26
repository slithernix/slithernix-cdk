#!/usr/bin/env ruby
require_relative 'example'

class PositionExample < Example
  def PositionExample.parse_opts(opts, param)
    opts.banner = 'Usage: position_ex.rb [options]'

    param.x_value = Cdk::CENTER
    param.y_value = Cdk::CENTER
    param.box = true
    param.shadow = false
    param.w_value = 40

    super(opts, param)

    opts.on('-w WIDTH', OptionParser::DecimalInteger, 'Field width') do |w|
      param.w_value = w
    end
  end

  # This demonstrates the positioning of a Cdk entry field widget.
  def PositionExample.main
    label = "</U/5>Directory:<!U!5> "
    params = parse(ARGV)

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Cdk::Draw.initCDKColor

    # Create the entry field widget.
    directory = Cdk::ENTRY.new(
      cdkscreen,
      params.x_value,
      params.y_value,
      '',
      label,
      Curses::A_NORMAL,
      '.',
      :MIXED,
      params.w_value,
      0,
      256,
      params.box,
      params.shadow,
    )

    # Is the widget nil?
    if directory.nil?
      # Clean up.
      cdkscreen.destroy
      Cdk::Screen.endCDK

      puts "Cannot create the entry box. Is the window too small?"
      exit  # EXIT_FAILURE
    end

    # Let the user move the widget around the window.
    directory.draw(directory.box)
    directory.position

    # Activate the entry field.
    info = directory.activate('')

    # Tell them what they typed.
    if directory.exit_type == :ESCAPE_HIT
      mesg = [
        "<C>You hit escape. No information passed back.",
        "",
        "<C>Press any key to continue."
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif directory.exit_type == :NORMAL
      mesg = [
        "<C>You typed in the following",
        "<C>%.*s" % [236, info],  # FIXME magic number
        "",
        "<C>Press any key to continue."
      ]

      cdkscreen.popupLabel(mesg, 4)
    end

    directory.destroy
    cdkscreen.destroy
    Cdk::Screen.endCDK
    #ExitProgram (EXIT_SUCCESS);
  end
end

PositionExample.main
