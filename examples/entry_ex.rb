#!/usr/bin/env ruby
require_relative 'example'

class EntryExample < Example
  def EntryExample.parse_opts(opts, param)
    opts.banner = 'Usage: dialog_ex.rb [options]'

    param.x_value = Slithernix::Cdk::CENTER
    param.y_value = Slithernix::Cdk::CENTER
    param.box = true
    param.shadow = false
    super(opts, param)
  end

  # This program demonstrates the Cdk dialog widget.
  def EntryExample.main
    title = "<C>Enter a\n<C>directory name."
    label = "</U/5>Directory:<!U!5>"

    params = parse(ARGV)

    # Set up CDK.
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Start color.
    Slithernix::Cdk::Draw.initCDKColor

    # Create the entry field widget.
    directory = Slithernix::Cdk::Widget::Entry.new(
      cdkscreen,
      params.x_value,
      params.y_value,
      title,
      label,
      Curses::A_NORMAL,
      '.',
      :MIXED,
      40,
      0,
      256,
      params.box,
      params.shadow,
    )

    xxxcb = lambda do |cdktype, widget, client_data, key|
      return true
    end

    directory.bind(:Entry, '?', xxxcb, 0)

    # Is the widget nil?
    if directory.nil?
      # Clean p
      cdkscreen.destroy
      Slithernix::Cdk::Screen.endCDK

      puts "Cannot create the entry box. Is the window too small?"
      exit
    end

    # Draw the screen.
    cdkscreen.refresh

    # Pass in whatever was given off of the command line.
    arg = ARGV.size > 0 ? ARGV[0] : nil
    directory.set(arg, 0, 256, true)

    # Activate the entry field.
    info = directory.activate('')

    # Tell them what they typed.
    case directory.exit_type
      when :ESCAPE_HIT
        mesg = [
          "<C>You hit escape. No information passed back.",
          "",
          "<C>Press any key to continue."
        ]
      when :NORMAL
        mesg = [
          "<C>You typed in the following",
          "<C>(%.*s)" % [246, info],  # FIXME: magic number
          "",
          "<C>Press any key to continue."
        ]
    end

    directory.destroy
    cdkscreen.popupLabel(mesg, mesg.size)
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    exit  # EXIT_SUCCESS
  end
end

EntryExample.main
