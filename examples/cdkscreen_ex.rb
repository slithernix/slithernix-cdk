#!/usr/bin/env ruby
require_relative 'example'

class CDKScreenExample < Example
  # This demonstrates how to create four different Cdk screens
  # and flip between them.
  def CDKScreenExample.main
    buttons = ["Continue", "Exit"]

    # Create the curses window.
    curses_win = Curses.init_screen

    # Create the screens
    cdkscreen1 = Cdk::Screen.new(curses_win)
    cdkscreen2 = Cdk::Screen.new(curses_win)
    cdkscreen3 = Cdk::Screen.new(curses_win)
    cdkscreen4 = Cdk::Screen.new(curses_win)
    cdkscreen5 = Cdk::Screen.new(curses_win)

    # Create the first screen.
    title1_mesg = [
        "<C><#HL(30)>",
        "<C></R>This is the first screen.",
        "<C>Hit space to go to the next screen",
        "<C><#HL(30)>"
    ]
    label1 = Cdk::LABEL.new(cdkscreen1, Cdk::CENTER, Cdk::TOP, title1_mesg,
                            4, false, false)

    # Create the second screen.
    title2_mesg = [
        "<C><#HL(30)>",
        "<C></R>This is the second screen.",
        "<C>Hit space to go to the next screen",
        "<C><#HL(30)>"
    ]
    label2 = Cdk::LABEL.new(cdkscreen2, Cdk::RIGHT, Cdk::CENTER, title2_mesg,
                            4, false, false)

    # Create the third screen.
    title3_mesg = [
        "<C><#HL(30)>",
        "<C></R>This is the third screen.",
        "<C>Hit space to go to the next screen",
        "<C><#HL(30)>"
    ]
    label3 = Cdk::LABEL.new(cdkscreen3, Cdk::CENTER, Cdk::BOTTOM, title3_mesg,
                            4, false, false)

    # Create the fourth screen.
    title4_mesg = [
        "<C><#HL(30)>",
        "<C></R>This is the fourth screen.",
        "<C>Hit space to go to the next screen",
        "<C><#HL(30)>"
    ]
    label4 = Cdk::LABEL.new(cdkscreen4, Cdk::LEFT, Cdk::CENTER, title4_mesg,
                            4, false, false)

    # Create the fifth screen.
    dialog_mesg = [
        "<C><#HL(30)>",
        "<C>Screen 5",
        "<C>This is the last of 5 screens. If you want",
        "<C>to continue press the 'Continue' button.",
        "<C>Otherwise press the 'Exit' button",
        "<C><#HL(30)>"
    ]
    dialog = Cdk::DIALOG.new(cdkscreen5, Cdk::CENTER, Cdk::CENTER, dialog_mesg,
                             6, buttons, 2, Curses::A_REVERSE, true, true, false)

    # Do this forever... (almost)
    while true
      # Draw the first screen.
      cdkscreen1.draw
      label1.wait(' ')
      cdkscreen1.erase

      # Draw the second screen.
      cdkscreen2.draw
      label2.wait(' ')
      cdkscreen2.erase

      # Draw the third screen.
      cdkscreen3.draw
      label3.wait(' ')
      cdkscreen3.erase

      # Draw the fourth screen.
      cdkscreen4.draw
      label4.wait(' ')
      cdkscreen4.erase

      # Draw the fifth screen
      cdkscreen5.draw
      answer = dialog.activate('')

      # Check the user's answer.
      if answer == 1
        label1.destroy
        label2.destroy
        label3.destroy
        label4.destroy
        dialog.destroy
        cdkscreen1.destroy
        cdkscreen2.destroy
        cdkscreen3.destroy
        cdkscreen4.destroy
        cdkscreen5.destroy
        Cdk::Screen.endCDK
        exit  # EXIT__SUCCESS
      end
    end
  end
end

CDKScreenExample.main
