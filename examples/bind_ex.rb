#!/usr/bin/env ruby
# frozen_string_literal: true

require 'etc'
require_relative 'example'

class BindExample < Example
  def self.parse_opts(opts, param)
    opts.banner = 'Usage: dialog_ex.rb [options]'

    param.x_value = Slithernix::Cdk::CENTER
    param.y_value = Slithernix::Cdk::CENTER
    param.box = true
    param.shadow = false
    super
  end

  def self.main
    params = parse(ARGV)

    # Set up CDK.
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Start color.
    Slithernix::Cdk::Draw.init_color

    # Set up the dialog box.
    message = [
      '<C></U>Simple Command Interface',
      'Pick the command you wish to run.',
      '<C>Press </R>?<!R> for help.'
    ]

    buttons = %w[Who Time Date Quit]

    # Create the dialog box
    question = Slithernix::Cdk::Widget::Dialog.new(cdkscreen, params.x_value, params.y_value,
                                                   message, 3, buttons, 4, Curses::A_REVERSE, true,
                                                   params.box, params.shadow)

    # Check if we got a nil value back.
    if question.nil?
      cdkscreen.destroy
      Slithernix::Cdk::Screen.end_cdk

      puts 'Cannot create the dialog box. Is the window too small?'
      exit # EXIT_FAILURE
    end

    dialog_help_cb = lambda do |_cdktype, dialog, _client_data, _key|
      # Check which button we are on
      if dialog.current_button.zero?
        mesg = [
          '<C></U>Help for </U>Who<!U>.',
          '<C>When this button is picked the name of the current',
          '<C>user is displayed on the screen in a popup window.',
        ]
        dialog.screen.popup_label(mesg, 3)
      elsif dialog.current_button == 1
        mesg = [
          '<C></U>Help for </U>Time<!U>.',
          '<C>When this button is picked the current time is',
          '<C>displayed on the screen in a popup window.'
        ]
        dialog.screen.popup_label(mesg, 3)
      elsif dialog.current_button == 2
        mesg = [
          '<C></U>Help for </U>Date<!U>.',
          '<C>When this button is picked the current date is',
          '<C>displayed on the screen in a popup window.'
        ]
        dialog.screen.popup_label(mesg, 3)
      elsif dialog.current_button == 3
        mesg = [
          '<C></U>Help for </U>Quit<!U>.',
          '<C>When this button is picked the dialog box is exited.'
        ]
        dialog.screen.popup_label(mesg, 2)
      end
      false
    end

    # Create the key binding.
    question.bind(:Dialog, '?', dialog_help_cb, 0)

    # Activate the dialog box.
    selection = 0
    while selection != 3
      # Get the users button selection
      selection = question.activate('')

      # Check the results.
      if selection.zero?
        # Get the users login name.
        info = ['<C>     </U>Login Name<!U>     ']
        login_name = Etc.getlogin
        info << if login_name.nil?
                then '<C></R>Unknown'
                else
                  format('<C><%.*s>', 246, login_name) # FIXME: magic number
                end

        question.screen.popup_label(info, 2)
      elsif selection == 1
        info = [
          '<C>   </U>Current Time<!U>   ',
          Time.new.getlocal.strftime('<C>%H:%M:%S')
        ]
        question.screen.popup_label(info, 2)
      elsif selection == 2
        info = [
          '<C>   </U>Current Date<!U>   ',
          Time.new.getlocal.strftime('<C>%d/%m/%y')
        ]
        question.screen.popup_label(info, 2)
      end
    end

    # Clean up and exit.
    question.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.end_cdk
    exit # EXIT_SUCCESS
  end
end

BindExample.main
