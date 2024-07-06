#!/usr/bin/env ruby
require 'optparse'
require 'ostruct'
require 'sqlite3'
require_relative '../lib/slithernix/cdk'

class SQLiteDemo
  MAXWIDTH = 5000
  MAXHISTORY = 1000
  GPUsage = '[-p Command Prompt] [-f databasefile] [-h help]'
  @@gp_current_database = ''
  @@gp_cdk_screen = nil

  # This saves the history into RC file.
  def self.saveHistory(history, _count)
    if (home = ENV.fetch('HOME', nil)).nil?
      home = '.'
    end
    filename = format('%s/.tawnysqlite.rc', home)

    # Open the file for writing.
    begin
      fd = File.open(filename, 'w')
    rescue StandardError
      return
    end

    # Start saving the history.
    history.cmd_history.each do |cmd|
      fd.puts cmd
    end

    fd.close
  end

  # This loads the history into the editor from the RC file.
  def self.loadHistory(history)
    home = ''
    filename = ''

    # Create the RC filename.
    if (home = ENV.fetch('HOME', nil)).nil?
      home = '.'
    end
    filename = format('%s/.tawnysqlite.rc', home)

    # Set some variables.
    history.current = 0

    # Read the file.
    if (history.count = Slithernix::Cdk.readFile(filename,
                                                 history.cmd_history)) != -1
      history.current = history.count
    end
  end

  # This displays a little introduction screen.
  def self.intro(screen)
    # Create the message.
    mesg = [
      '',
      '<C></B/16>SQLite Command Interface',
      '<C>Written By Chris Sauro',
      '',
      '<C>Type </B>help<!B> to get help.',
    ]

    # Display the message.
    screen.popupLabel(mesg, mesg.size)
  end

  def self.help(entry)
    # Create the help message.
    mesg = [
      '<C></B/29>Help',
      '',
      '</B/24>When in the command line.',
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
      '<B=Tab or Esc> Returns to the command line.',
      '<B=?         > Displays this help window.',
      '',
      '<C> (</B/24>Refer to the scrolling window online manual for more help<!B!24.)',
    ]

    # Pop up the help message.
    entry.screen.popupLabel(mesg, mesg.size)
  end

  def self.main
    history = OpenStruct.new
    history.used = 0
    history.count = 0
    history.current = 0
    history.cmd_history = []
    count = 0

    prompt = ''
    dbfile = ''
    opts = OptionParser.getopts('p:f:h')
    prompt = opts['p'] if opts['p']
    dbfile = opts['f'] if opts['f']
    if opts['h']
      puts format('Usage: %s %s', File.basename($PROGRAM_NAME),
                  SQLiteDemo::GPUsage)
      exit # EXIT_SUCCESS
    end

    dsquery = ''

    # Set up the command prompt.
    if prompt == ''
      prompt = if dbfile == ''
                 '</B/24>Command >'
               else
                 format('</B/24>[%s] Command >', prompt)
               end
    end

    # Set up CDK
    curses_win = Curses.init_screen
    @@gp_cdk_screen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.initCDKColor

    begin
      sqlitedb = SQLite3::Database.new(dbfile)
    rescue StandardError
      mesg = ['<C></U>Fatal Error', '<C>Could not connect to the database.']
      @gp_cdk_screen.popupLabel(mesg, mesg.size)
      exit # EXIT_FAILURE
    end

    # Load the history.
    SQLiteDemo.loadHistory(history)

    # Create the scrolling window.
    command_output = Slithernix::Cdk::Widget::SWindow.new(@@gp_cdk_screen, Slithernix::Cdk::CENTER, Slithernix::Cdk::TOP,
                                                          -8, -2, '<C></B/5>Command Output Window', SQLiteDemo::MAXWIDTH,
                                                          true, false)

    # Create the entry field.
    width = Curses.cols - prompt.size - 1
    command_entry = Slithernix::Cdk::Widget::Entry.new(@@gp_cdk_screen, Slithernix::Cdk::CENTER, Slithernix::Cdk::BOTTOM,
                                                       '', prompt, Curses::A_BOLD | Curses.color_pair(8),
                                                       Curses.color_pair(24) | '_'.ord, :MIXED, width, 1, 512, false, false)

    # Create the key bindings.

    history_up_cb = lambda do |_cdktype, entry, history, _key|
      # Make sure we don't go out of bounds
      if history.current.zero?
        Slithernix::Cdk.Beep
        return true
      end

      # Decrement the counter.
      history.current -= 1

      # Display the command.
      entry.setValue(history.cmd_history[history.current])
      entry.draw(entry.box)
      true
    end

    history_down_cb = lambda do |_cdktype, entry, history, _key|
      # Make sure we don't go out of bounds.
      if history.current == history.count
        Slithernix::Cdk.Beep
        return true
      end

      # Increment the counter...
      history.current += 1

      # If we are at the end, clear the entry field.
      if history.current == history.count
        entry.clean
        entry.draw(entry.box)
        return true
      end

      # Display the command.
      entry.setValue(history.cmd_history[history.current])
      entry.draw(entry.box)
      true
    end

    list_history_cb = lambda do |_cdktype, entry, history, _key|
      height = [history.count, 10].min + 3

      # No history, no list.
      if history.count.zero?
        # Popup a little window telling the user there are no commands.
        mesg = ['<C></B/16>No Commands Entered', '<C>No History']
        entry.screen.popupLabel(mesg, mesg.size)

        # Redraw the screen.
        entry.erase
        entry.screen.draw

        # And leave...
        return true
      end

      # Create the scrolling list of previous commands.
      scroll_list = Slithernix::Cdk::Widget::Scroll.new(entry.screen, Slithernix::Cdk::CENTER, Slithernix::Cdk::CENTER,
                                                        Slithernix::Cdk::RIGHT, height, -10, '<C></B/29>Command History',
                                                        history.cmd_history, history.count, true, Curses::A_REVERSE,
                                                        true, false)

      # Get the command to execute.
      selection = scroll_list.activate([])
      scroll_list.destroy

      # Check the results of the selection.
      if selection >= 0
        # Get the command and stick it back in the entry field.
        entry.setValue(history.cmd_history[selection])
      end

      # Redraw the screen.
      entry.erase
      entry.screen.draw
      true
    end

    view_history_cb = lambda do |_cdktype, entry, swindow, _key|
      swindow.activate([])
      entry.draw(entry.box)
      true
    end

    swindow_help_cb = lambda do |_cdktype, _widget, entry, _key|
      SQLiteDemo.help(entry)
      true
    end

    command_entry.bind(:Entry, Curses::KEY_UP, history_up_cb, history)
    command_entry.bind(:Entry, Curses::KEY_DOWN, history_down_cb, history)
    command_entry.bind(:Entry, Slithernix::Cdk.CTRL('^'), list_history_cb,
                       history)
    command_entry.bind(:Entry, Slithernix::Cdk::KEY_TAB, view_history_cb,
                       command_output)
    command_output.bind(:SWindow, '?', swindow_help_cb, command_entry)

    # Draw the screen.
    @@gp_cdk_screen.refresh

    # Display the introduction window.
    SQLiteDemo.intro(@@gp_cdk_screen)

    loop do
      # Get the command.
      command = command_entry.activate([]).strip
      upper = command.upcase

      # Check the output of the command.
      if %w[QUIT EXIT Q E].include?(upper) ||
         command_entry.exit_type == :ESCAPE_HIT
        # Save the history.
        SQLiteDemo.saveHistory(history, 100)

        # Exit
        sqlitedb.close unless sqlitedb.closed?

        # All done.
        command_entry.destroy
        command_output.destroy
        Slithernix::Cdk::Screen.endCDK
        exit # EXIT_SUCCESS
      elsif command == 'clear'
        # Clear the scrolling window.
        command_output.clean
      elsif command == 'history'
        list_history_cb.call(:Entry, command_entry, history, nil)
        next
      elsif command == 'tables'
        command = "SELECT * FROM sqlite_master WHERE type='table';"
        command_output.add(format('</R>%d<!R> %s', count + 1, command),
                           Slithernix::Cdk::BOTTOM)
        count += 1
        sqlitedb.execute(command) do |row|
          command_output.add(row[2], Slithernix::Cdk::BOTTOM) if row.size >= 3
        end
      elsif command == 'help'
        # Display the help.
        SQLiteDemo.help(command_entry)
      else
        command_output.add(format('</R>%d<!R> %s', count + 1, command),
                           Slithernix::Cdk::BOTTOM)
        count += 1
        begin
          sqlitedb.execute(command) do |row|
            command_output.add(row.join(' '), Slithernix::Cdk::BOTTOM)
          end
        rescue Exception => e
          command_output.add(format('Error: %s', e.message),
                             Slithernix::Cdk::BOTTOM)
        end
      end

      # Keep the history.
      history.cmd_history << command
      history.count += 1
      history.used += 1
      history.current = history.count

      # Clear the entry field.
      command_entry.clean
    end

    # Clean up
    @@gp_cdk_screen.destroy
    Slithernix::Cdk::Screen.endCDK
    exit # EXIT_SUCCESS
  end
end

SQLiteDemo.main
