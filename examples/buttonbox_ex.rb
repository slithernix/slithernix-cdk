#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'example'

class ButtonboxExample < Example
  # This program demonstrates the Cdk buttonbox widget.
  def self.main
    buttons = [' OK ', ' Cancel ']

    # Set up CDK.
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Start color.
    Slithernix::Cdk::Draw.init_color

    # Create the entry widget.
    entry = Slithernix::Cdk::Widget::Entry.new(
      cdkscreen,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::CENTER,
      '<C>Enter a name',
      'Name ',
      Curses::A_NORMAL,
      '.',
      :MIXED,
      40,
      0,
      256,
      true,
      false
    )

    if entry.nil?
      cdkscreen.destroy
      Slithernix::Cdk::Screen.end_cdk

      warn 'Cannot create entry-widget'
      exit
    end

    # Create the button box widget.
    button_widget = Slithernix::Cdk::Widget::ButtonBox.new(
      cdkscreen,
      entry.win.begx,
      entry.win.begy + entry.box_height - 1,
      1,
      entry.box_width - 1,
      '',
      1,
      2,
      buttons,
      2,
      Curses::A_REVERSE,
      true,
      false
    )

    if button_widget.nil?
      cdkscreen.destroy
      Slithernix::Cdk::Screen.end_cdk

      warn 'Cannot create buttonbox-widget'
      exit
    end

    # Set the lower left and right characters of the box.
    entry.setLLchar(Slithernix::Cdk::ACS_LTEE)
    entry.setLRchar(Slithernix::Cdk::ACS_RTEE)
    button_widget.setULchar(Slithernix::Cdk::ACS_LTEE)
    button_widget.setURchar(Slithernix::Cdk::ACS_RTEE)

    # Bind the Tab key in the entry field to send a
    # Tab key to the button box widget.
    entryCB = lambda do |_cdktype, _widget, client_data, key|
      client_data.inject(key)
      true
    end

    entry.bind(:Entry, Slithernix::Cdk::KEY_TAB, entryCB, button_widget)

    # Activate the entry field.
    button_widget.draw(true)
    info = entry.activate('')
    selection = button_widget.current_button

    # Clean up.
    button_widget.destroy
    entry.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.end_cdk

    puts format('You typed in (%s) and selected button (%s)',
                info&.size&.positive? ? info : '<null>', buttons[selection])
    exit # EXIT_SUCCESS
  end
end

ButtonboxExample.main
