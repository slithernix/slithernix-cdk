#!/usr/bin/env ruby
require_relative 'example'

class PreProcessExample < Example
  # This program demonstrates the Cdk preprocess feature.
  def PreProcessExample.main
    title = "<C>Type in anything you want\n<C>but the dreaded letter </B>G<!B>!"

    # Set up CDK.
    curses_win = Curses.init_screen
    cdkscreen = Cdk::Screen.new(curses_win)

    # Start color.
    Cdk::Draw.initCDKColor

    # Create the entry field widget.
    widget = Cdk::ENTRY.new(cdkscreen, Cdk::CENTER, Cdk::CENTER,
                            title, '', Curses::A_NORMAL, '.', :MIXED, 40, 0, 256,
                            true, false)

    if widget.nil?
      # Clean up
      cdkscreen.destroy
      Cdk.endCDK

      puts "Cannot create the entry box. Is the window too small?"
      exit  # EXIT_FAILURE
    end

    entry_pre_process_cb = lambda do |cdktype, entry, client_data, input|
      buttons = ["OK"]
      button_count = 1
      mesg = []

      # Check the input.
      if input == 'g' || input == 'G'
        mesg << "<C><#HL(30)>"
        mesg << "<C>I told you </B>NOT<!B> to type G"
        mesg << "<C><#HL(30)>"

        dialog = Cdk::DIALOG.new(entry.screen, Cdk::CENTER, Cdk::CENTER,
                                 mesg, mesg.size, buttons, button_count, Curses::A_REVERSE,
                                 false, true, false)
        dialog.activate('')
        dialog.destroy
        entry.draw(entry.box)
        return 0
      end
      return 1
    end

    widget.setPreProcess(entry_pre_process_cb, nil)

    # Activate the entry field.
    info = widget.activate('')

    # Tell them what they typed.
    if widget.exit_type == :ESCAPE_HIT
      mesg = [
          "<C>You hit escape. No information passed back.",
          "",
          "<C>Press any key to continue."
      ]

      cdkscreen.popupLabel(mesg, 3)
    elsif widget.exit_type == :NORMAL
      mesg = [
          "<C>You typed in the following",
          "<C>(%.*s)" % [236, info],  # FIXME: magic number
          "",
          "<C>Press any key to continue."
      ]

      cdkscreen.popupLabel(mesg, 4)
    end

    # Clean up and exit.
    widget.destroy
    cdkscreen.destroy
    Cdk::Screen.endCDK
    exit  # EXIT_SUCCESS
  end
end

PreProcessExample.main
