#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'fileutils'
require_relative '../lib/slithernix/cdk'

class Vinstall
  FPUsage = '-f filename [-s source directory] [-d destination directory] ' \
            '[-t title] [-o Output file] [q]'

  # Copy the file.
  def self.copyFile(_cdkscreen, src, dest)
    # TODO: error handling
    FileUtils.cp(src, dest)
    :OK
  end

  # This makes sure the given directory exists.  If it doesn't then it will
  # make it.
  def self.verifyDirectory(cdkscreen, directory)
    status = 0
    buttons = %w[
      Yes
      No
    ]
    unless Dir.exist?(directory)
      # Create the question.
      mesg = [
        '<C>The directory',
        format('<C>%.256s', directory),
        '<C>Does not exist. Do you want to',
        '<C>create it?',
      ]

      # Ask them if they want to create the directory.
      if cdkscreen.popup_dialog(mesg, mesg.size, buttons, buttons.size).zero?
        # TODO: error handling
        if Dir.mkdir(directory, 0o755) != 0
          # Create the error message.
          error = [
            '<C>Could not create the directory',
            format('<C>%.256s', directory),
            # '<C>%.256s' % [strerror (errno)]
            '<C>Check the permissions and try again.',
          ]

          # Pop up the error message.
          cdkscreen.popup_label(error, error.size)

          status = -1
        end
      else
        # Create the message
        error = ['<C>Installation aborted.']

        # Pop up the error message.
        cdkscreen.popup_label(error, error.size)

        status = -1
      end
    end
    status
  end

  def self.main
    source_path = String.new
    dest_path = String.new
    filename = String.new
    title = String.new
    output = String.new
    quiet = false

    # Check the command line for options
    opts = OptionParser.getopts('d:s:f:t:o:q')
    dest_path = opts['d'] if opts['d']
    source_path = opts['s'] if opts['s']
    filename = opts['f'] if opts['f']
    title = opts['t'] if opts['t']
    output = opts['o'] if opts['o']
    quiet = true if opts['q']

    # Make sure we have everything we need.
    if filename == ''
      warn format('Usage: %s %s', File.basename($PROGRAM_NAME),
                  Vinstall::FPUsage)
      exit # EXIT_FAILURE
    end

    file_list = []
    # Open the file list file and read it in.
    count = Slithernix::Cdk.readFile(filename, file_list)
    if count.zero?
      warn format('%s: Input filename <%s> is empty.', ARGV[0], filename)
    end

    # Cycle through what was given to us and save it.
    file_list.each(&:strip!)

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.init_color

    # Create the title label.
    title_mesg = [
      '<C></32/B<#HL(30)>',
      if title == ''
        '<C></32/B>CDK Installer'
      else
        format('<C></32/B>%.256s',
               title)
      end,
      '<C></32/B><#HL(30)>'
    ]
    title_win = Slithernix::Cdk::Widget::Label.new(
      cdkscreen,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::TOP,
      title_mesg,
      3,
      false,
      false,
    )

    source_entry = nil
    dest_entry = nil

    # Allow them to change the install directory.
    if source_path == ''
      source_entry = Slithernix::Cdk::Widget::Entry.new(
        cdkscreen,
        Slithernix::Cdk::CENTER,
        8,
        '',
        'Source Directory        :',
        Curses::A_NORMAL,
        '.'.ord,
        :MIXED,
        40,
        0,
        256,
        true,
        false,
      )
    end

    if dest_path == ''
      dest_entry = Slithernix::Cdk::Widget::Entry.new(
        cdkscreen,
        Slithernix::Cdk::CENTER,
        11,
        '',
        'Destination Directory:',
        Curses::A_NORMAL,
        '.'.ord,
        :MIXED,
        40,
        0,
        256,
        true,
        false,
      )
    end

    # Get the source install path.
    source_dir = source_path
    unless source_entry.nil?
      cdkscreen.draw
      source_dir = source_entry.activate([])
    end

    # Get the destination install path.
    dest_dir = dest_path
    unless dest_entry.nil?
      cdkscreen.draw
      dest_dir = dest_entry.activate([])
    end

    # Destroy the path entry fields.
    source_entry&.destroy
    dest_entry&.destroy

    # Verify that the source directory is valid.
    if Vinstall.verifyDirectory(cdkscreen, source_dir) != 0
      # Clean up and leave.
      title_win.destroy
      cdkscreen.destroy
      Slithernix::Cdk::Screen.end_cdk
      exit # EXIT_FAILURE
    end

    # Verify that the destination directory is valid.
    if Vinstall.verifyDirectory(cdkscreen, dest_dir) != 0
      title_win.destroy
      cdkscreen.destroy
      Slithernix::Cdk::Screen.end_cdk
      exit # EXIT_FAILURE
    end

    # Create the histogram.
    progress_bar = Slithernix::Cdk::Widget::Histogram.new(
      cdkscreen,
      Slithernix::Cdk::CENTER,
      5,
      3,
      0,
      Slithernix::Cdk::HORIZONTAL,
      '<C></56/B>Install Progress',
      true,
      false,
    )

    # Set the top left/right characters of the histogram.
    progress_bar.setLLchar(Slithernix::Cdk::ACS_LTEE)
    progress_bar.setLRchar(Slithernix::Cdk::ACS_RTEE)

    # Set the initial value fo the histgoram.
    progress_bar.set(
      :PERCENT,
      Slithernix::Cdk::TOP,
      Curses::A_BOLD,
      1,
      count,
      1,
      Curses.color_pair(24) | Curses::A_REVERSE | ' '.ord,
      true,
    )

    # Determine the height of the scrolling window.
    swindow_height = Curses.lines - 13 if Curses.lines >= 16

    # Create the scrolling window.
    install_output = Slithernix::Cdk::Widget::SWindow.new(
      cdkscreen,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::BOTTOM,
      swindow_height,
      0,
      '<C></56/B>Install Results',
      2000,
      true,
      false
    )

    # Set the top left/right characters of the scrolling window.
    install_output.setULchar(Slithernix::Cdk::ACS_LTEE)
    install_output.setURchar(Slithernix::Cdk::ACS_RTEE)

    # Draw the screen.
    cdkscreen.draw

    errors = 0

    # Start copying the files.
    (0...count).each do |x|
      # If the 'file' list file has 2 columns, the first is the source
      # filename, the second being the destination
      files = file_list[x].split
      old_path = format('%s/%s', source_dir, file_list[x])
      new_path = format('%s/%s', dest_dir, file_list[x])
      if files.size == 2
        # Create the correct paths.
        old_path = format('%s/%s', source_dir, files[0])
        new_path = format('%s/%s', dest_dir, files[1])
      end

      # Copy the file from the source to the destiation.
      ret = Vinstall.copyFile(cdkscreen, old_path, new_path)
      temp = String.new
      if ret == :CanNotOpenSource
        temp = format('</16>Error: Can not open source file "%.256s"<!16>',
                      old_path)
        errors += 1
      elsif ret == :CanNotOpenDest
        temp = format(
          '</16>Error: Can not open destination file "%.256s"<!16>', new_path
        )
        errors += 1
      else
        temp = format('</25>%.256s -> %.256s', old_path, new_path)
      end

      # Add the message to the scrolling window.
      install_output.add(temp, Slithernix::Cdk::BOTTOM)
      install_output.draw(install_output.box)

      # Update the histogram.
      progress_bar.set(:PERCENT, Slithernix::Cdk::TOP, Curses::A_BOLD, 1, count,
                       x + 1, Curses.color_pair(24) | Curses::A_REVERSE | ' '.ord, true)

      # Update the screen.
      progress_bar.draw(true)
    end

    # If there were errors, inform the user and allow them to look at the
    # errors in the scrolling window.
    if errors.positive?
      # Create the information for the dialog box.
      buttons = [
        'Look At Errors Now',
        'Save Output To A File',
        'Ignore Errors',
      ]
      mesg = [
        '<C>There were errors in the installation.',
        '<C>If you want, you may scroll through the',
        '<C>messages of the scrolling window to see',
        '<C>what the errors were. If you want to save',
        '<C>the output of the window you may press</R>s<!R>',
        '<C>while in the window, or you may save the output',
        '<C>of the install now and look at the install',
        '<C>histoyr at a later date.'
      ]

      # Popup the dialog box.
      ret = cdkscreen.popup_dialog(mesg, mesg.size, buttons, buttons.size)

      if ret.zero?
        install_output.activate([])
      elsif ret == 1
        install_output.inject('s')
      end
    elsif output != ''
      # If they specified the name of an output file, then save the
      # results of the installation to that file.
      install_output.dump(output)
    elsif quiet == false
      # Ask them if they want to save the output of the scrolling window.
      buttons = %w[
        No
        Yes
      ]
      mesg = [
        '<C>Do you want to save the output of the',
        '<C>scrolling window to a file?',
      ]

      if cdkscreen.popup_dialog(mesg, 2, buttons, 2) == 1
        install_output.inject('s')
      end
    end

    # Clean up.
    title_win.destroy
    progress_bar.destroy
    install_output.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.end_cdk
    exit # EXIT_SUCCESS
  end
end

Vinstall.main
