#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require_relative '../lib/slithernix/cdk'

class FileView
  def self.main
    params = OptionParser.getopts('d:f:')
    filename = params['f'] || ''
    directory = params['d'] || '.'

    # Create the viewer buttons.
    button = [
      '</5><OK><!5>',
      '</5><Cancel><!5>',
    ]

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.initCDKColor

    # Get the filename
    if filename == ''
      title = '<C>Pick a file.'
      label = 'File: '
      fselect = Slithernix::Cdk::Widget::FSelect.new(cdkscreen, Slithernix::Cdk::CENTER, Slithernix::Cdk::CENTER,
                                                     20, 65, title, label, Curses::A_NORMAL, '_', Curses::A_REVERSE,
                                                     '</5>', '</48>', '</N>', '</N>', true, false)

      # Set the starting directory.  This is not necessary because when
      # the file selector starts it uses the present directory as a default.
      fselect.set(directory, Curses::A_NORMAL, '.', Curses::A_REVERSE,
                  '</5>', '</48>', '</N>', '</N>', fselect.box)

      # Activate the file selector.
      filename = fselect.activate([])

      # Check how the person exited from the widget.
      if fselect.exit_type == :ESCAPE_HIT
        # pop up a message for the user.
        mesg = [
          '<C>Escape hit. No file selected.',
          '',
          '<C>Press any key to continue.',
        ]
        cdkscreen.popupLabel(mesg, 3)

        fselect.destroy

        cdkscreen.destroy
        Slithernix::Cdk::Screen.endCDK

        exit # EXIT_SUCCESS
      end

      fselect.destroy
    end

    # Create the file viewer to view the file selected.
    example = Slithernix::Cdk::Widget::Viewer.new(cdkscreen, Slithernix::Cdk::CENTER, Slithernix::Cdk::CENTER, 20, -2,
                                                  button, 2, Curses::A_REVERSE, true, false)

    # Could we create the viewer widget?
    if example.nil?
      # Clean up the memory.
      cdkscreen.destroy

      # End curses...
      Slithernix::Cdk.endCDK

      puts 'Cannot create viewer. Is the window too small?'
      exit # EXIT_FAILURE
    end

    # Open the file and read the contents.

    info = []
    lines = Slithernix::Cdk.readFile(filename, info)
    if lines == -1
      puts format('Could not open %s', filename)
      exit # EXIT_FAILURE
    end

    # Set up the viewer title and the contents to the widget.
    title = '<C></B/22>%20s<!22!B>' % filename
    example.set(title, info, lines, Curses::A_REVERSE, true, true, true)

    # Activate the viewer widget.
    selected = example.activate([])

    # Check how the person exited from the widget.
    if example.exit_type == :ESCAPE_HIT
      mesg = [
        '<C>Escape hit. No Button selected.',
        '',
        '<C>Press any key to continue.',
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif example.exit_type == :NORMAL
      mesg = [
        format('<C>You selected button %d', selected),
        '',
        '<C>Press any key to continue.',
      ]
      cdkscreen.popupLabel(mesg, 3)
    end

    # Clean up
    example.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    # ExitProgram (EXIT_SUCCESS);
  end
end

FileView.main
