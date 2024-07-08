#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'example'

class PreProcessExample < Example
  # This program demonstrates the Cdk preprocess feature.
  def self.main
    title = "<C>Type in anything you want\n<C>but the dreaded letter </B>G<!B>!"

    # Set up CDK.
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Start color.
    Slithernix::Cdk::Draw.init_color

    # Create the entry field widget.
    widget = Slithernix::Cdk::Widget::Entry.new(cdkscreen, Slithernix::Cdk::CENTER, Slithernix::Cdk::CENTER,
                                                title, '', Curses::A_NORMAL, '.', :MIXED, 40, 0, 256,
                                                true, false)

    if widget.nil?
      # Clean up
      cdkscreen.destroy
      Slithernix::Cdk.end_cdk

      puts 'Cannot create the entry box. Is the window too small?'
      exit # EXIT_FAILURE
    end

    entry_pre_process_cb = lambda do |_cdktype, entry, _client_data, input|
      buttons = ['OK']
      button_count = 1
      mesg = []

      # Check the input.
      if %w[g G].include?(input)
        mesg << '<C><#HL(30)>'
        mesg << '<C>I told you </B>NOT<!B> to type G'
        mesg << '<C><#HL(30)>'

        dialog = Slithernix::Cdk::Widget::Dialog.new(entry.screen, Slithernix::Cdk::CENTER, Slithernix::Cdk::CENTER,
                                                     mesg, mesg.size, buttons, button_count, Curses::A_REVERSE,
                                                     false, true, false)
        dialog.activate('')
        dialog.destroy
        entry.draw(entry.box)
        return 0
      end
      1
    end

    widget.set_pre_process(entry_pre_process_cb, nil)

    # Activate the entry field.
    info = widget.activate('')

    # Tell them what they typed.
    if widget.exit_type == :ESCAPE_HIT
      mesg = [
        '<C>You hit escape. No information passed back.',
        '',
        '<C>Press any key to continue.'
      ]

      cdkscreen.popup_label(mesg, 3)
    elsif widget.exit_type == :NORMAL
      mesg = [
        '<C>You typed in the following',
        format('<C>(%.*s)', 236, info), # FIXME: magic number
        '',
        '<C>Press any key to continue.'
      ]

      cdkscreen.popup_label(mesg, 4)
    end

    # Clean up and exit.
    widget.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.end_cdk
    exit # EXIT_SUCCESS
  end
end

PreProcessExample.main
