#!/usr/bin/env ruby
require 'ostruct'
require 'optparse'
require_relative '../lib/slithernix/cdk'

class Command
  MAXHISTORY = 5000

  def Command.help(entry)
    # Create the help message.
    mesg = [
        '<C></B/29>Help',
        '',
        '</B/24>When in the command line.',
        '<B=history   > Displays the command history.',
        '<B=Ctrl-^    > Displays the command history.',
        '<B=Up Arrow  > Scrolls back one command.',
        '<B=Down Arrow> Scrolls forward one command.',
        '<B=Tab       > Activates the scrolling window.',
        '<B=help      > Displays this help window.',
        '',
        '</B/24>When in the scrolling window.',
        '<B=l or L    > Loads a file into the window.',
        '<B=s or S    > Saves the contents of the window to a file.',
        '<B=Up Arrow  > Scrolls up one line.',
        '<B=Down Arrow> Scrolls down one line.',
        '<B=Page Up   > Scrolls back one page.',
        '<B=Page Down > Scrolls forward one page.',
        '<B=Tab/Escape> Returns to the command line.',
        '',
        '<C> (</B/24>Refer to the scrolling window online manual ' <<
            'for more help<!B!24>.)'
    ]
    entry.screen.popupLabel(mesg, mesg.size)
  end

  def Command.main
    intro_mesg = [
        '<C></B/16>Little Command Interface',
        '',
        '<C>Written by Chris Sauro',
        '',
        '<C>Type </B>help<!B> to get help.'
    ]
    command = ''
    prompt = '</B/24>Command >'
    title = '<C></B/5>Command Output Window'

    # Set up the history
    history = OpenStruct.new
    history.count = 0
    history.current = 0
    history.command = []

    # Check the command line for options
    opts = OptionParser.getopts('t:p:')
    if opts['p']
      prompt = opts['p']
    end
    if opts['t']
      title = opts['t']
    end

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Cdk::Draw.initCDKColor

    # Create the scrolling window.
    command_output = Cdk::SWINDOW.new(cdkscreen, Cdk::CENTER, Cdk::TOP,
                                      -8, -2, title, 1000, true, false)

    # Convert the prompt to a chtype and determine its length
    prompt_len = []
    convert = Cdk.char2Chtype(prompt, prompt_len, [])
    prompt_len = prompt_len[0]
    command_field_width = Curses.cols - prompt_len - 4

    # Create the entry field.
    command_entry = Cdk::ENTRY.new(cdkscreen, Cdk::CENTER, Cdk::BOTTOM,
                                   '', prompt, Curses::A_BOLD | Curses.color_pair(8),
                                   Curses.color_pair(24) | '_'.ord, :MIXED,
                                   command_field_width, 1, 512, false, false)

    # Create the key bindings.
    history_up_cb = lambda do |cdktype, entry, history, key|
      # Make sure we don't go out of bounds
      if history.current == 0
        Cdk.Beep
        return false
      end

      # Decrement the counter.
      history.current -= 1

      # Display the command.
      entry.setValue(history.command[history.current])
      entry.draw(entry.box)
      return false
    end

    history_down_cb = lambda do |cdktype, entry, history, key|
      # Make sure we don't go out of bounds
      if history.current == @count
        Cdk.Beep
        return false
      end

      # Increment the counter.
      history.current += 1

      # If we are at the end, clear the entry field.
      if history.current == history.count
        entry.clean
        entry.draw(entry.box)
        return false
      end

      # Display the command.
      entry.setValue(history.command[history.current])
      entry.draw(entry.box)
      return false
    end

    view_history_cb = lambda do |cdktype, entry, swindow, key|
      # Let them play...
      swindow.activate([])

      # Redraw the entry field.
      entry.draw(entry.box)
      return false
    end

    list_history_cb = lambda do |cdktype, entry, history, key|
      height = if history.count < 10 then history.count + 3 else 13 end

      # No history, no list.
      if history.count == 0
        # Popup a little message telling the user there are no comands.
        mesg = [
            '<C></B/16>No Commands Entered',
            '<C>No History',
        ]
        entry.screen.popupLabel(mesg, 2)

        # Redraw the screen.
        entry.erase
        entry.screen.draw

        # And leave...
        return false
      end

      # Create the scrolling list of previous commands.
      scroll_list = Cdk::SCROLL.new(entry.screen, Cdk::CENTER, Cdk::CENTER,
                                    Cdk::RIGHT, height, 20, '<C></B/29>Command History',
                                    history.command, history.count, true, Curses::A_REVERSE,
                                    true, false)

      # Get the command to execute.
      selection = scroll_list.activate([])
      scroll_list.destroy

      # Check the results of the selection.
      if selection >= 0
        # Get the command and stick it back in the entry field
        entry.setValue(history.command[selection])
      end

      # Redraw the screen.
      entry.erase
      entry.screen.draw
      return false
    end

    jump_window_cb = lambda do |cdktype, entry, swindow, key|
      # Ask them which line they want to jump to.
      scale = Cdk::SCALE.new(entry.screen, Cdk::CENTER, Cdk::CENTER,
                             '<C>Jump To Which Line', 'Line', Curses::A_NORMAL, 5,
                             0, 0, swindow.list_size, 1, 2, true, false)

      # Get the line.
      line = scale.activate([])

      # Clean up.
      scale.destroy

      # Jump to the line.
      swindow.jumpToLine(line)

      # Redraw the widgets.
      entry.draw(entry.box)
      return false
    end

    command_entry.bind(:ENTRY, Curses::KEY_UP, history_up_cb, history)
    command_entry.bind(:ENTRY, Curses::KEY_DOWN, history_down_cb, history)
    command_entry.bind(:ENTRY, Cdk::KEY_TAB, view_history_cb, command_output)
    command_entry.bind(:ENTRY, Cdk.CTRL('^'), list_history_cb, history)
    command_entry.bind(:ENTRY, Cdk.CTRL('G'), jump_window_cb, command_output)

    # Draw the screen.
    cdkscreen.refresh

    # Show them who wrote this and how to get help.
    cdkscreen.popupLabel(intro_mesg, intro_mesg.size)
    command_entry.erase

    # Do this forever.
    while true
      # Get the command
      command_entry.draw(command_entry.box)
      command = command_entry.activate([])
      upper = command.upcase

      # Check the output of the command
      if ['QUIT', 'EXIT', 'Q', 'E'].include?(upper) ||
          command_entry.exit_type == :ESCAPE_HIT
        # All done.
        command_entry.destroy
        command_output.destroy
        cdkscreen.destroy

        Cdk::Screen.endCDK

        exit  # EXIT_SUCCESS
      elsif command == 'clear'
        # Keep the history.
        history.command << command
        history.count += 1
        history.current = history.count
        command_output.clean
        command_entry.clean
      elsif command == 'history'
        # Display the history list.
        list_history_cb.call(:ENTRY, command_entry, history, 0)

        # Keep the history.
        history.command << command
        history.count += 1
        history.current = history.count
      elsif command == 'help'
        # Keep the history
        history.command << command
        history.count += 1
        history.current = history.count

        # Display the help.
        Command.help(command_entry)

        # Clean the entry field.
        command_entry.clean
        command_entry.erase
      else
        # Keep the history
        history.command << command
        history.count += 1
        history.current = history.count

        # Jump to the bottom of the scrolling window.
        command_output.jumpToLine(Cdk::BOTTOM)

        # Insert a line providing the command.
        command_output.add('Command: </R>%s' % [command], Cdk::BOTTOM)

        # Run the command
        command_output.exec(command, Cdk::BOTTOM)

        # Clean out the entry field.
        command_entry.clean
      end
    end
  end
end

Command.main
