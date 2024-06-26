#!/usr/bin/env ruby
require_relative 'example'

class ButtonboxExample < Example
  # This program demonstrates the Cdk buttonbox widget.
  def ButtonboxExample.main
    buttons = [" OK ", " Cancel "]

    # Set up CDK.
    curses_win = Curses.init_screen
    cdkscreen = Cdk::Screen.new(curses_win)

    # Start color.
    Cdk::Draw.initCDKColor

    # Create the entry widget.
    entry = Cdk::ENTRY.new(cdkscreen, Cdk::CENTER, Cdk::CENTER,
                           "<C>Enter a name", "Name ", Curses::A_NORMAL, '.', :MIXED,
                           40, 0, 256, true, false)

    if entry.nil?
      cdkscreen.destroy
      Cdk::Screen.endCDK

      $stderr.puts "Cannot create entry-widget"
      exit # EXIT_FAILURE
    end

    # Create the button box widget.
    button_widget = Cdk::BUTTONBOX.new(cdkscreen,
                                       entry.win.begx, entry.win.begy + entry.box_height - 1,
                                       1, entry.box_width - 1, '', 1, 2, buttons, 2, Curses::A_REVERSE,
                                       true, false)

    if button_widget.nil?
      cdkscreen.destroy
      Cdk::Screen.endCDK

      $stderr.puts "Cannot create buttonbox-widget"
      exit # EXIT_FAILURE
    end

    # Set the lower left and right characters of the box.
    entry.setLLchar(Cdk::ACS_LTEE)
    entry.setLRchar(Cdk::ACS_RTEE)
    button_widget.setULchar(Cdk::ACS_LTEE)
    button_widget.setURchar(Cdk::ACS_RTEE)

    # Bind the Tab key in the entry field to send a
    # Tab key to the button box widget.
    entryCB = lambda do |cdktype, object, client_data, key|
      client_data.inject(key)
      return true
    end

    entry.bind(:ENTRY, Cdk::KEY_TAB, entryCB, button_widget)

    # Activate the entry field.
    button_widget.draw(true)
    info = entry.activate('')
    selection = button_widget.current_button

    # Clean up.
    button_widget.destroy
    entry.destroy
    cdkscreen.destroy
    Cdk::Screen.endCDK

    puts "You typed in (%s) and selected button (%s)" % [
        if !(info.nil?) && info.size > 0 then info else '<null>' end,
        buttons[selection]
    ]
    exit # EXIT_SUCCESS
  end
end

ButtonboxExample.main
