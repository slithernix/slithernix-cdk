#!/usr/bin/env ruby
# frozen_string_literal: true

require 'ostruct'
require_relative '../lib/slithernix/cdk'

class Rolodex
  MAXGROUPS = 100
  GTypeMap = {
    UNKNOWN: -1,
    VOICE: 0,
    CELL: 1,
    PAGER: 2,
    FAX1: 3,
    FAX2: 4,
    FAX3: 5,
    DATA1: 6,
    DATA2: 7,
    DATA3: 8
  }.freeze
  GTypeReverseMap = {
    -1 => :UNKNOWN,
    0 => :VOICE,
    1 => :CELL,
    2 => :PAGER,
    3 => :FAX1,
    4 => :FAX2,
    5 => :FAX3,
    6 => :DATA1,
    7 => :DATA2,
    8 => :DATA3
  }.freeze
  GLineType = [
    'Voice',
    'Cell',
    'Pager',
    'First FAX',
    'Second FAX',
    'Third FAX',
    'First Data Line',
    'Second Data Line',
    'Third Data Line',
  ].freeze

  @@g_current_group = String.new
  @@grc_file = String.new
  @@gdbm_dir = String.new
  @@g_group_modified = false

  def self.printGroup(group_record, filename, printer)
    uid = Process::Sys.getuid

    phone_data = OpenStruct.new
    phone_data.record = []
    phone_data.count = 0
    Rolodex.readPhoneDataFile(group_record.dbm, phone_data)

    # Create the temporary filename
    temp_filename = if filename == ''
                    then format('/tmp/rolodex.%d', uid)
                    else
                      filename
                    end

    # Open the file.
    begin
      fd = File.open(temp_filename, 'a+')
    rescue StandardError
      return 0
    end

    # Start writing the group information to the temp file.
    fd.puts format('Group Name: %40s', group_record.name)
    fd.puts '=' * 78
    phone_data.record.each do |phone_record|
      fd.puts format('Name        : %s', phone_record.name)
      fd.puts format(
        'Phone Number: %s (%s)',
        phone_record.phone_number,
        Rolodex::GLineType[Rolodex::GTypeMap[phone_record.line_type]]
      )

      unless %i[PAGER CELL].include? phone_record.line_type
        fd.puts format(
          'Address     : %-20s, %-20s',
          phone_record.address,
          phone_record.city,
        )

        fd.puts format(
          '            : %-10s, %-10s',
          phone_record.province,
          phone_record.postal_code
        )
      end
      fd.puts format('Description : %-30s', phone_record.desc)
      fd.puts '-' * 78
    end

    fd.close

    # Determine if the information is going to a file or printer.
    if printer != ''
      # Print the file to the given printer.
      command = format('lpr -P%s %s', printer, temp_filename)
      system(command)

      # We have to unlink the temp file.
      begin
        File.unlink(temp_filename)
      rescue StandardError
      end
    end

    1
  end

  # This prints a group's phone numbers.
  def self.printGroupNumbers(screen, group_list, group_count)
    choices = [
      'Print to Printer',
      'Print to File',
      "Don't Print",
    ]

    item_list = group_list.map do |group|
      group.name.clone
    end

    # Set the height of the selection list.
    height = [group_count, 5].min + 3

    # Create the selection list.
    selection_list = Slithernix::Cdk::Widget::Selection.new(
      screen,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::RIGHT,
      height,
      40,
      '<C></U>Select Which Groups To Print',
      item_list,
      group_count,
      choices,
      choices.size,
      Curses::A_REVERSE,
      true,
      false,
    )

    # Activate the selection list.
    if selection_list.activate([]) == -1
      # Tell the user they exited early.
      selection_list.destroy
      mesg = ['<C>Print Canceled.']
      screen.popup_label(mesg, mesg.size)
      return
    end
    selection_list.erase

    # Determine which groups we want to print.
    (0...group_count).each do |x|
      if selection_list.selections[x].zero?
        # Create a title.
        mesg = [
          format(
            '<C></R>Printing Group [%s] to Printer',
            group_list[x].name
          )
        ]
        title = Slithernix::Cdk::Widget::Label.new(
          screen,
          Slithernix::Cdk::CENTER,
          Slithernix::Cdk::TOP,
          mesg,
          mesg.size,
          false,
          false,
        )
        title.draw(false)

        # Get the printer name to print to.
        entry = Slithernix::Cdk::Widget::Entry.new(
          screen,
          Slithernix::Cdk::CENTER,
          8,
          '',
          '</R>Printer Name: ',
          Curses::A_NORMAL,
          '_'.ord,
          :MIXED,
          20,
          2,
          256,
          true,
          false
        )

        # Set the printer name to the default printer
        default_printer = ENV['PRINTER'] || ''
        entry.set(default_printer, 2, 256, true)
        printer = entry.activate([])
        entry.destroy

        # Print the group
        if Rolodex.printGroup(group_list[x], '/tmp/rolodex.tmp', printer).zero?
          # The group could not be printed.
          mesg = [
            format(
              "<C>Sorry the group '%s' could not be printed",
              group_list[x].name,
            )
          ]
          screen.popup_label(screen, mesg, mesg.size)
        end

        title.destroy
        begin
          File.unlink('/tmp/rolodex.tmp')
        rescue StandardError
        end
      elsif selection_list.selections[x] == 1
        # Create a title.
        mesg = [
          format(
            '<C></R>Printing Group [%s] to File',
            group_list[x].name
          )
        ]
        title = Slithernix::Cdk::Widget::Label.new(
          screen,
          Slithernix::Cdk::CENTER,
          Slithernix::Cdk::TOP,
          mesg,
          mesg.size,
          false,
          false,
        )
        title.draw(false)

        # Get the filename to print to.
        entry = Slithernix::Cdk::Widget::Entry.new(
          screen,
          Slithernix::Cdk::CENTER,
          8,
          '',
          '</R>Filename: ',
          Curses::A_NORMAL,
          '_'.ord,
          :MIXED,
          20,
          2,
          256,
          true,
          false,
        )
        filename = entry.activate([])
        entry.destroy

        # Print the group.
        if Rolodex.printGroup(group_list[x], filename, '').zero?
          # The group could not be printed.
          mesg = [
            format(
              "<C>Sorry the group '%s' could not be printed.",
              group_list[x].name
            )
          ]
          screen.popup_label(mesg, mesg.size)
        end

        title.destroy
      end
    end

    # Clean up.
    selection_list.destroy
  end

  # This deletes a rolodex group.
  def self.deleteRolodexGroup(screen, group_list, group_count)
    # If there are no groups, pop up a message telling them.
    if group_count.zero?
      mesg = [
        '<C>Error',
        '<C>There are no groups defined.',
      ]
      screen.popup_label(mesg, mesg.size)

      # Return the current group count
      return group_count
    end

    # Get the number of the group to delete.
    selection = Rolodex.pickRolodexGroup(
      screen,
      '<C></U>Delete Which Rolodex Group?',
      group_list,
      group_count,
    )

    # Check the results.
    if selection.negative?
      mesg = [
        '<C>   Delete Canceled   ',
        '<C>No Group Deleted',
      ]
      screen.popup_label(mesg, mesg.size)
      return group_count
    end

    # Let's make sure they want to delete the group.
    mesg = [
      '<C></U>Confirm Delete',
      '<C>Are you sure you want to delete the group',
      format('<C></R>%s<!R>?', group_list[selection].name),
    ]

    buttons = [
      '<No>',
      '<Yes>',
    ]
    choice = screen.popup_dialog(mesg, mesg.size, buttons, buttons.size)

    # Check the results of the confirmation.
    if choice.zero?
      mesg = [
        '<C>   Delete Canceled   ',
        '<C>No Group Deleted',
      ]
      screen.popup_label(mesg, mesg.size)
      return group_count
    end

    # We need to delete the group file first
    begin
      File.unlink(group_list[selection].dbm)
    rescue StandardError
    end

    # OK, let's delete the group
    # front = group_list[0...selection]
    # back = group_list[selection+1..-1]
    # group_list = front + back
    group_list.delete_at(selection)
    group_count -= 1
    @@g_group_modified = true

    group_count
  end

  # This function gets information about a new phone number.
  def self.addPhoneRecord(screen, phone_data)
    # Get the phone record
    phone_data.record[phone_data.count] =
      phone_data.record[phone_data.count] || OpenStruct.new
    phone_record = phone_data.record[phone_data.count]

    # Create a title label to display.
    title_mesg = ['<C></B/16>Add New Phone Record']
    title = Slithernix::Cdk::Widget::Label.new(
      screen,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::TOP,
      title_mesg,
      title_mesg.size,
      false,
      false,
    )
    title.draw(false)

    # Create the phone line type list.
    types = Rolodex::GLineType.map do |type|
      format('<C></U>%s', type)
    end

    # Get the phone line type.
    item_list = Slithernix::Cdk::Widget::ItemList.new(
      screen,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::CENTER,
      '<C>What Type Of Line Is It?',
      'Type: ',
      types,
      types.size,
      0,
      true,
      false,
    )
    phone_record.line_type = Rolodex::GTypeReverseMap[item_list.activate([])]
    item_list.destroy

    # Check the return code of the line type question.
    if phone_record.line_type == :UNKNOWN
      phone_record.line_type = :VOICE
      return 1
    elsif %i[PAGER CELL].include?(phone_record.line_type)
      ret = Rolodex.getSmallPhoneRecord(screen, phone_record)
    else
      ret = Rolodex.getLargePhoneRecord(screen, phone_record)
    end

    # Check the return value from the getXXXPhoneRecord function.
    phone_data.count += 1 if ret.zero?

    # Clean up
    title.destroy

    # Return the new phone list count.
    ret
  end

  # This gets a phone record with all the details
  def self.getLargePhoneRecord(screen, phone_record)
    # Define the widget.
    name_entry = Slithernix::Cdk::Widget::Entry.new(
      screen,
      Slithernix::Cdk::LEFT,
      5,
      '',
      '</B/5>Name: ',
      Curses::A_NORMAL,
      '_'.ord,
      :MIXED,
      20,
      2,
      256,
      true,
      false,
    )

    address_entry = Slithernix::Cdk::Widget::Entry.new(
      screen,
      Slithernix::Cdk::RIGHT,
      5,
      '',
      '</B/5>Address: ',
      Curses::A_NORMAL,
      '_'.ord,
      :MIXED,
      40,
      2,
      256,
      true,
      false,
    )

    city_entry = Slithernix::Cdk::Widget::Entry.new(
      screen,
      Slithernix::Cdk::LEFT,
      8,
      '',
      '</B/5>City: ',
      Curses::A_NORMAL,
      '_'.ord,
      :MIXED,
      20,
      2,
      256,
      true,
      false
    )

    prov_entry = Slithernix::Cdk::Widget::Entry.new(
      screen,
      29,
      8,
      '',
      '</B/5>Province: ',
      Curses::A_NORMAL,
      '_'.ord,
      :MIXED,
      15,
      2,
      256,
      true,
      false
    )

    postal_entry = Slithernix::Cdk::Widget::Entry.new(
      screen,
      Slithernix::Cdk::RIGHT,
      8,
      '',
      '</B/5>Postal Code: ',
      Curses::A_NORMAL,
      '_'.ord,
      :UMIXED,
      8,
      2,
      256,
      true,
      false,
    )

    phone_template = Slithernix::Cdk::Widget::Template.new(
      screen,
      Slithernix::Cdk::LEFT,
      11,
      '',
      '</B/5>Number: ',
      '(###) ###-####',
      '(___) ___-____',
      true,
      false,
    )

    desc_entry = Slithernix::Cdk::Widget::Entry.new(
      screen,
      Slithernix::Cdk::RIGHT,
      11,
      '',
      '</B/5>Description: ',
      Curses::A_NORMAL,
      '_'.ord,
      :MIXED,
      20,
      2,
      256,
      true,
      false
    )

    # Get the phone information.
    loop do
      # Draw the widget on the screen.
      name_entry.draw(name_entry.box)
      address_entry.draw(address_entry.box)
      city_entry.draw(city_entry.box)
      prov_entry.draw(prov_entry.box)
      postal_entry.draw(postal_entry.box)
      phone_template.draw(phone_template.box)
      desc_entry.draw(desc_entry.box)

      # Activate the entries to get the information.
      phone_record.name = name_entry.activate([])
      phone_record.address = address_entry.activate([])
      phone_record.city = city_entry.activate([])
      phone_record.province = prov_entry.activate([])
      phone_record.postal_code = postal_entry.activate([])
      phone_template.activate([])
      phone_record.phone_number = phone_template.mix
      phone_record.desc = desc_entry.activate([])

      # Determine if the user wants to submit the info.
      mesg = [
        '<C></B/5>Confirm New Phone Entry',
        '<C>Do you want to add this phone number?',
      ]
      buttons = [
        '</B/24><Add Phone Number>',
        '</B/16><Cancel>',
        '</B/8><Modify Information>',
      ]
      ret = screen.popup_dialog(mesg, mesg.size, buttons, buttons.size)

      # Check the response of the popup dialog box.
      if ret.zero?
        # The user wants to submit the information.
        name_entry.destroy
        address_entry.destroy
        city_entry.destroy
        prov_entry.destroy
        postal_entry.destroy
        desc_entry.destroy
        phone_template.destroy
        return ret
      elsif ret == 1
        # The user does not want to submit the information
        phone_record.name = String.new
        phone_record.phone_number = String.new
        phone_record.desc = String.new
        phone_record.address = String.new
        phone_record.city = String.new
        phone_record.province = String.new
        phone_record.postal_code = String.new

        name_entry.destroy
        address_entry.destroy
        city_entry.destroy
        prov_entry.destroy
        postal_entry.destroy
        desc_entry.destroy
        phone_template.destroy
        return ret
      else
        # The user wants to edit the information given
        phone_record.name = String.new
        phone_record.phone_number = String.new
        phone_record.desc = String.new
        phone_record.address = String.new
        phone_record.city = String.new
        phone_record.province = String.new
        phone_record.postal_code = String.new
      end
    end
  end

  # This gets a small phone record.
  def self.getSmallPhoneRecord(screen, phone_record)
    # Define the widget.
    name_entry = Slithernix::Cdk::Widget::Entry.new(
      screen,
      Slithernix::Cdk::CENTER,
      8,
      '',
      '</B/5>Name: ',
      Curses::A_NORMAL,
      '_'.ord,
      :MIXED,
      20,
      2,
      256,
      true,
      false,
    )

    phone_template = Slithernix::Cdk::Widget::Template.new(
      screen,
      Slithernix::Cdk::CENTER,
      11,
      '',
      '</B/5>Number: ',
      '(###) ###-####',
      '(___) ___-____',
      true,
      false,
    )

    desc_entry = Slithernix::Cdk::Widget::Entry.new(
      screen,
      Slithernix::Cdk::CENTER,
      14,
      '',
      '</B/5>Description: ',
      Curses::A_NORMAL,
      '_'.ord,
      :MIXED,
      20,
      2,
      256,
      true,
      false,
    )

    # Get the phone information.
    loop do
      # Draw the widget on the screen.
      name_entry.draw(name_entry.box)
      phone_template.draw(phone_template.box)
      desc_entry.draw(desc_entry.box)

      # Activate the entries to get the information.
      phone_record.name = name_entry.activate([])
      phone_template.activate([])
      phone_record.phone_number = phone_template.mix
      phone_record.desc = desc_entry.activate([])
      phone_record.address = '-'
      phone_record.city = '-'
      phone_record.province = '-'
      phone_record.postal_code = '-'

      # Determine if the user wants to submit the info.
      mesg = [
        '<C></B/5>Confirm New Phone Entry',
        '<C>Do you want to add this phone number?',
      ]
      buttons = [
        '</B/24><Add Phone Number>',
        '</B/16><Cancel>',
        '</B/8><Modify Information>',
      ]
      ret = screen.popup_dialog(mesg, mesg.size, buttons, buttons.size)

      # Check the response of the popup dialog box.
      if ret.zero?
        # The user wants to submit the information.
        name_entry.destroy
        desc_entry.destroy
        phone_template.destroy
        return ret
      elsif ret == 1
        # The user does not want to submit the information
        phone_record.name = String.new
        phone_record.phone_number = String.new
        phone_record.desc = String.new
        phone_record.address = String.new
        phone_record.city = String.new
        phone_record.province = String.new
        phone_record.postal_code = String.new

        name_entry.destroy
        desc_entry.destroy
        phone_template.destroy
        return ret
      else
        # The user wants to edit the information given
        phone_record.name = String.new
        phone_record.phone_number = String.new
        phone_record.desc = String.new
        phone_record.address = String.new
        phone_record.city = String.new
        phone_record.province = String.new
        phone_record.postal_code = String.new
      end
    end
  end

  # This opens a new RC file.
  def self.openNewRCFile(screen, group_list, group_count)
    # Get the filename
    file_selector = Slithernix::Cdk::Widget::FSelect.new(screen,
                                                         Slithernix::Cdk::CENTER,
                                                         Slithernix::Cdk::CENTER,
                                                         20,
                                                         55,
                                                         '<C>Open RC File',
                                                         'Filename: ',
                                                         Curses::A_NORMAL,
                                                         '.'.ord,
                                                         Curses::A_REVERSE,
                                                         '</5>',
                                                         '</48>',
                                                         '</N>',
                                                         '</N>',
                                                         true,
                                                         false,)

    # Activate the file selector.
    filename = file_selector.activate([])

    # Check if the file selector left early.
    if file_selector.exit_type == :ESCAPE_HIT
      file_selector.destroy
      mesg = ['Open New RC File Aborted.']
      screen.popup_label(mesg, mesg.size)
      return group_count
    end

    # Clean out the old information
    group_list.clear

    # Open the RC file
    group_count = Rolodex.readRCFile(filename, group_list)

    # Check the return value.
    if group_count.negative?
      # This file does not appear to be a rolodex file.
      mesg = [
        '<C></B/16>The file<!B!16>',
        format('<C></B/16>(%s)<!B!16>', filename),
        '<C>does not seem to be a rolodex RC file.',
        '<C>Press any key to continue.'
      ]
      screen.popup_label(mesg, mesg.size)
      group_count = 0
    end

    # Clean up
    file_selector.destroy
    group_count
  end

  # This reads the user's rc file.
  def self.readRCFile(filename, group_list)
    groups_found = 0
    errors_found = 0
    lines = []

    # Open the file and start reading.
    lines_read = Slithernix::Cdk.readFile(filename, lines)

    # Check the number of lines read.
    return 0 if lines_read.zero?

    # Cycle through what was given to us and save it.
    (0...lines_read).each do |x|
      # Strip white space from the line.
      lines[x].strip!

      # Only split lines which do not start with a #
      next unless lines[x].size.positive? && lines[x][0] != '#'

      items = lines[x].split(Slithernix::Cdk.CTRL('V').chr)

      # Only take the ones which fit the format.
      if items.size == 3
        # Clean off the name and DB name
        items[0].strip!
        items[1].strip!
        items[2].strip!

        # Set the group anme and DB name
        group_list << OpenStruct.new
        group_list[groups_found].name = items[0]
        group_list[groups_found].desc = items[1]
        group_list[groups_found].dbm = items[2]
        groups_found += 1
      else
        errors_found += 1
      end
    end

    # Check the number of groups to the number of errors.
    if errors_found.positive? && groups_found.zero?
      # This does NOT look like the rolodex RC file.
      return -1
    end

    groups_found
  end

  # This writes out the new RC file.
  def self.writeRCFile(screen, filename, group_list, group_count)
    # TODO: error handling
    fd = File.new(filename, 'w')

    time = Time.now.getlocal

    # Put some comments at the top of the header
    fd.puts '#'
    fd.puts '# This file was automatically generated on %s' % time.ctime
    fd.puts '#'

    # Start writing the RC file.
    group_list.each do |group|
      fd.puts format(
        '%s%c%s%c%s',
        group.name,
        Slithernix::Cdk.CTRL('V').chr,
        group.desc,
        Slithernix::Cdk.CTRL('V').chr,
        group.dbm
      )
    end

    fd.close

    mesg = []
    mesg << format(
      'There were %d group%s saved to file',
      group_count,
      group_count == 1 ? '' : 's',
    )

    mesg << ('<C>%s' % filename)
    mesg << '<C>Press any key to continue.'

    screen.popup_label(mesg, mesg.size)

    1
  end

  # This function gets a new rc filename and saves the contents of the
  # groups under that name.
  def self.writeRCFileAs(screen, group_list, group_count)
    # Create the entry field.
    new_rc_file = Slithernix::Cdk::Widget::Entry.new(
      screen,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::CENTER,
      '<C></R>Save As',
      'Filename: ',
      Curses::A_NORMAL,
      '_'.ord,
      :MIXED,
      20,
      2,
      256,
      true,
      false,
    )

    # Add a pre-process function so no spaces are introduced.
    entry_pre_process_cb = lambda do |_cdk_type, _widget, _client_data, input|
      if input.ord == ' '.ord
        Slithernix::Cdk.Beep
        return 0
      end
      1
    end
    new_rc_file.setPreProcess(entry_pre_process_cb, nil)

    # Get the filename.
    new_filename = new_rc_file.activate([])

    # Check if they hit escape or not.
    if new_rc_file.exit_type == :ESCAPE_HIT
      new_rc_file.destroy
      return 1
    end

    # Call the function to save the RC file.
    ret = Rolodex.writeRCFile(screen, new_filename, group_list, group_count)

    # Reset the saved flag if the rc file saved ok.
    if ret != 0
      # Change the default filename
      @@grc_file = new_filename.clone
      @@g_group_modified = false
    end

    # Clean up.
    new_rc_file.destroy
    1
  end

  # This opens a phone data file and returns the number of elements read
  def self.readPhoneDataFile(data_file, phone_data)
    lines = []

    lines_read = Slithernix::Cdk.readFile(data_file, lines)
    lines_found = 0

    # Check the number of lines read.
    return 0 if lines_read <= 0

    # Cycle through what was given to us and save it.
    (0...lines_read).each do |x|
      next unless lines[x].size.positive? && lines[x][0] != '#'

      # Split the string.
      items = lines[x].split(Slithernix::Cdk.CTRL('V').chr)

      if items.size == 8
        phone_data.record[lines_found] =
          phone_data.record[lines_found] || OpenStruct.new
        phone_data.record[lines_found].name = items[0]
        phone_data.record[lines_found].line_type =
          Rolodex::GTypeReverseMap[items[1].to_i]
        phone_data.record[lines_found].phone_number = items[2]
        phone_data.record[lines_found].address = items[3]
        phone_data.record[lines_found].city = items[4]
        phone_data.record[lines_found].province = items[5]
        phone_data.record[lines_found].postal_code = items[6]
        phone_data.record[lines_found].desc = items[7]
        lines_found += 1
      elsif items.size == 7
        phone_data.record[lines_found] =
          phone_data.record[lines_found] || OpenStruct.new
        phone_data.record[lines_found].name = items[0]
        phone_data.record[lines_found].line_type =
          Rolodex::GTypeReverseMap[items[1].to_i]
        phone_data.record[lines_found].phone_number = items[2]
        phone_data.record[lines_found].address = items[3]
        phone_data.record[lines_found].city = items[4]
        phone_data.record[lines_found].province = items[5]
        phone_data.record[lines_found].postal_code = items[6]
        phone_data.record[lines_found].desc = String.new
        lines_found += 1
      else
        # Bad line in the file
        Slithernix::Cdk::Screen.endCDK
        puts 'Bad line of size %d' % items.size
        print items
        puts
        exit
      end
    end

    # Keep the record count and return.
    phone_data.count = lines_found
    lines_found
  end

  # This writes a phone data file and returns the number of elements written.
  def self.savePhoneDataFile(filename, phone_data)
    # TODO: add error handling
    fd = File.new(filename, 'w')

    # Get the current time
    time = Time.now.getlocal

    # Add the header to the file.
    fd.puts '#'
    fd.puts format('# This file was automatically saved on %s', time.ctime)
    fd.puts format(
      '# There should be %d phone numbers in this file.',
      phone_data.count,
    )
    fd.puts '#'

    # Cycle through the data and start writing it to the file.
    phone_data.record.each do |phone_record|
      # Check the phone type.
      if %i[CELL PAGER].include?(phone_record.line_type)
        fd.puts format(
          '%s%c%d%c%s%c-%c-%c-%c-%c%s',
          phone_record.name,
          Slithernix::Cdk.CTRL('V').chr,
          Rolodex::GTypeMap[phone_record.line_type],
          Slithernix::Cdk.CTRL('V').chr,
          phone_record.phone_number,
          Slithernix::Cdk.CTRL('V').chr,
          Slithernix::Cdk.CTRL('V').chr,
          Slithernix::Cdk.CTRL('V').chr,
          Slithernix::Cdk.CTRL('V').chr,
          Slithernix::Cdk.CTRL('V').chr,
          phone_record.desc
        )
      else
        fd.puts format(
          '%s%c%d%c%s%c%s%c%s%c%s%c%s',
          phone_record.name,
          Slithernix::Cdk.CTRL('V').chr,
          Rolodex::GTypeMap[phone_record.line_type],
          Slithernix::Cdk.CTRL('V').chr,
          phone_record.phone_number,
          Slithernix::Cdk.CTRL('V').chr,
          phone_record.address,
          Slithernix::Cdk.CTRL('V').chr,
          phone_record.city,
          Slithernix::Cdk.CTRL('V').chr,
          phone_record.province,
          Slithernix::Cdk.CTRL('V').chr,
          phone_record.postal_code,
          Slithernix::Cdk.CTRL('V').chr,
          phone_record.desc
        )
      end
    end
    fd.close
    1
  end

  # This displays the information about the phone record.
  def self.displayPhoneInfo(screen, record)
    # Check the type of line it is.
    mesg = if %i[VOICE DATA1 DATA2 DATA3 FAX1 FAX2 FAX2].include?(
      record.line_type
    )
             # Create the information to display.
             [
               format('<C></U>%s Phone Record',
                      Rolodex::GLineType[Rolodex::GTypeMap[record.line_type]]),
               format('</B/29>Name        <!B!29>%s', record.name),
               format('</B/29>Phone Number<!B!29>%s', record.phone_number),
               format('</B/29>Address     <!B!29>%s', record.address),
               format('</B/29>City        <!B!29>%s', record.city),
               format('</B/29>Province    <!B!29>%s', record.province),
               format('</B/29>Postal Code <!B!29>%s', record.postal_code),
               format('</B/29>Comment     <!B!29>%s', record.desc),
             ]

           # Pop the information up on the screen
           elsif %i[PAGER CELL].include?(record.line_type)
             # Create the information to display.
             [
               format('<C></U>%s Phone Record',
                      Rolodex::GLineType[Rolodex::GTypeMap[record.line_type]]),
               format('</B/29>Name        <!B!29>%s', record.name),
               format('</B/29>Phone Number<!B!29>%s', record.phone_number),
               format('</B/29>Comment     <!B!29>%s', record.desc),
             ]

           # Pop the information up on the screen.
           else
             [
               '<C></R>Error<!R> </U>Unknown Phone Line Type',
               '<C>Can not display information.',
             ]
           end
    screen.popup_label(mesg, mesg.size)
  end

  # This function allows the user to add/delete/modify/save the
  # contents of a rolodex group.
  def self.useRolodexGroup(screen, group_name, _group_desc, group_dbm)
    # Set up the help window at the bottom of the screen.
    title = [
      '<C><#HL(30)>',
      '<C>Press </B>?<!B> to get detailed help.',
      '<C><#HL(30)>',
    ]
    help_window = Slithernix::Cdk::Widget::Label.new(
      screen,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::BOTTOM,
      title,
      title.size,
      false,
      false,
    )
    help_window.draw(false)

    # Open the DBM file and read in the contents of the file
    phone_data = OpenStruct.new
    phone_data.record = []
    phone_count = Rolodex.readPhoneDataFile(group_dbm, phone_data)
    phone_data.count = phone_count

    # Check the number of entries returned.
    if phone_count.zero?
      # They tried to open an empty group, maybe they want to
      # add a new entry to this number.
      buttons = [
        '<Yes>',
        '<No>',
      ]
      mesg = [
        '<C>There were no entries in this group.',
        '<C>Do you want to add a new listing?',
      ]
      if screen.popup_dialog(mesg, mesg.size, buttons, buttons.size) == 1
        help_window.destroy
        return
      end

      # Get the information for a new number.
      return if Rolodex.addPhoneRecord(screen, phone_data) != 0
    elsif phone_count.negative?
      mesg = ['<C>Could not open the database for this group.']
      screen.popup_label(mesg, mesg.size)
      help_window.destroy
      return
    end

    # Set up the data needed for the scrolling list.
    index = phone_data.record.map do |phone_record|
      format('</B/29>%s (%s)', phone_record.name,
             Rolodex::GLineType[Rolodex::GTypeMap[phone_record.line_type]])
    end
    temp = format('<C>Listing of Group </U>%s', group_name)
    height = [phone_data.count, 5].min + 3

    # Create the scrolling list.
    name_list = Slithernix::Cdk::Widget::Scroll.new(
      screen,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::RIGHT,
      height,
      50,
      temp,
      index,
      phone_data.count,
      true,
      Curses::A_REVERSE,
      true,
      false,
    )

    # This allows the user to insert a new phone entry into the database.
    insert_phone_entry_cb = lambda do |_cdk_type, scrollp, phone_data, _key|
      phone_data.record[phone_data.count] =
        phone_data.record[phone_data.count] || OpenStruct.new
      phone_record = phone_data.record[phone_data.count]

      # Make the scrolling list disappear.
      scrollp.erase

      # Call the function which gets phone record information.
      if Rolodex.addPhoneRecord(scrollp.screen, phone_data).zero?
        temp = format(
          '%s (%s)',
          phone_record.name,
          Rolodex::GLineType[Rolodex::GTypeMap[phone_record.line_type]]
        )
        scrollp.addItem(temp)
      end

      # Redraw the scrolling list.
      scrollp.draw(scrollp.box)
      false
    end

    # This allows the user to delete a phone entry from the database.
    delete_phone_entry_cb = lambda do |_cdk_type, scrollp, phone_data, _key|
      buttons = [
        '</B/16><No>',
        '</B/24><Yes>',
      ]
      position = scrollp.current_item

      # Make the scrolling list disappear..
      scrollp.erase

      # Check the number of entries left in the list.
      if scrollp.list_size.zero?
        mesg = ['There are no more numbers to delete.']
        scrollp.screen.popup_label(mesg, mesg.size)
        return false
      end

      # Ask the user if they really want to delete the listing.
      mesg = [
        '<C>Do you really want to delete the phone entry.',
        format(
          '<C></B/16>%s',
          Slithernix::Cdk.chtype2Char(scrollp.item[scrollp.current_item]),
        ),
      ]
      if scrollp.screen.popup_dialog(mesg, mesg.size, buttons,
                                     buttons.size) == 1
        front = phone_data.record[0...position] || []
        back = phone_data.record[position + 1..] || []
        phone_data.record = front + back
        phone_data.count -= 1

        # Nuke the entry.
        scrollp.deleteItem(position)
      end

      # Redraw the scrolling list.
      scrollp.draw(scrollp.box)
      false
    end

    # This function provides help for the phone list editor.
    phone_entry_help_cb = lambda do |_cdk_type, scrollp, _client_data, _key|
      mesg = [
        '<C></R>Rolodex Phone Editor',
        '<B=i     > Inserts a new phone entry.',
        '<B=d     > Deletes the currently selected phone entry.',
        '<B=Escape> Exits the scrolling list.',
        '<B=?     > Pops up this help window.',
      ]

      scrollp.screen.popup_label(mesg, 5)

      false
    end

    # Create key bindings.
    name_list.bind(:Scroll, 'i', insert_phone_entry_cb, phone_data)
    name_list.bind(:Scroll, 'd', delete_phone_entry_cb, phone_data)
    name_list.bind(:Scroll, Curses::KEY_DC, delete_phone_entry_cb, phone_data)
    name_list.bind(:Scroll, '?', phone_entry_help_cb, nil)

    # Let them play.
    selection = 0
    while selection >= 0
      # Get the information they want to view.
      selection = name_list.activate([])

      # Display the information.
      if selection >= 0
        # Display the information.
        Rolodex.displayPhoneInfo(screen, phone_data.record[selection])
      end
    end

    # Save teh rolodex information to file.
    if Rolodex.savePhoneDataFile(group_dbm, phone_data).zero?
      # Something happened.
      mesg = [
        '<C>Could not save phone data to data file.',
        '<C>All changes have been lost.'
      ]
      screen.popup_label(mesg, mesg.size)
    end

    # Clean up.
    name_list.destroy
    help_window.destroy
  end

  # This allows the user to pick a DBM file to open.
  def self.pickRolodexGroup(screen, title, group_list, group_count)
    height = [group_count, 5].min + 3

    # Copy the names of the scrolling list into an array.
    mesg = group_list.map do |group|
      format('<C></B/29>%s', group.name)
    end

    # Create the scrolling list.
    rolo_list = Slithernix::Cdk::Widget::Scroll.new(
      screen,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::NONE,
      height,
      50,
      title,
      mesg,
      mesg.size,
      false,
      Curses::A_REVERSE,
      true,
      false,
    )

    # This is a callback to the group list scrolling list.
    group_info_cb = lambda do |_cdk_type, scrollp, group_list, _key|
      selection = scrollp.current_item

      # Create the message to be displayed.
      mesg = [
        '<C></U>Detailed Group Information.',
        format('</R>Group Name         <!R> %s', group_list[selection].name),
        format('</R>Group Description  <!R> %s', group_list[selection].desc),
        format('</R>Group Database File<!R> %s', group_list[selection].dbm),
      ]

      # Display the message.
      scrollp.screen.popup_label(mesg, mesg.size)

      # Redraw the scrolling list.
      scrollp.draw(scrollp.box)
      false
    end
    # Create a callback to the scrolling list.
    rolo_list.bind(:Scroll, '?', group_info_cb, group_list)

    # Activate the scrolling list.
    selection = rolo_list.activate([])

    # Destroy the scrolling list.
    rolo_list.destroy

    # return the item selected.
    selection
  end

  # This allows the user to add a rolo group to the list.
  def self.addRolodexGroup(screen, group_list, group_count)
    # Create the name widget.
    new_name = Slithernix::Cdk::Widget::Entry.new(
      screen,
      Slithernix::Cdk::CENTER,
      8,
      '<C></B/29>New Group Name',
      '</B/29>   Name: ',
      Curses::A_NORMAL,
      '_'.ord,
      :MIXED,
      20,
      2,
      256,
      true,
      false,
    )

    # Get the name.
    new_group_name = new_name.activate([])

    # Make sure they didn't hit escape
    if new_name.exit_type == :ESCAPE_HIT
      mesg = ['<C></B/16>Add Group Canceled.']
      new_name.destroy
      screen.popup_label(mesg, mesg.size)
      return group_count
    end

    # Make sure that group name does not already exist.
    group_list.each do |group|
      next unless new_group_name == group.name

      mesg = [
        format(
          '<C></B/16>Sorry the group (%s) already exists.',
          new_group_name,
        )
      ]
      screen.popup_label(mesg, mesg.size)
      new_name.destroy
      return group_count
    end

    # Keep the name
    group_list[group_count] = OpenStruct.new
    group_list[group_count].name = new_group_name

    # Create the description widget.
    new_desc = Slithernix::Cdk::Widget::Entry.new(
      screen,
      Slithernix::Cdk::CENTER,
      13,
      '<C></B/29>Group Description',
      '</B/29>Description: ',
      Curses::A_NORMAL,
      '_'.ord,
      :MIXED,
      20,
      2,
      256,
      true,
      false,
    )

    # Get the description.
    desc = new_desc.activate([])

    # Check if they hit escape or not.
    group_list[group_count].desc = if new_desc.exit_type == :ESCAPE_HIT
                                     'No Description Provided.'
                                   else
                                     desc
                                   end

    # Create the DBM filename.
    group_list[group_count].dbm = format(
      '%s/%s.phl',
      @@gdbm_dir,
      group_list[group_count].name,
    )

    # Increment the group count.
    group_count += 1
    @@g_group_modified = 1

    # Destroy the widget.
    new_name.destroy
    new_desc.destroy
    group_count
  end

  # This displays rolodex information.
  def self.displayRolodexStats(screen, group_count)
    # Create the information to display.
    mesg = [
      '<C></U>Rolodex Statistics',
      format('</B/5>Read Command Filename<!B!5> </U>%s<!U>', @@grc_file),
      format('</B/5>Group Count          <!B!5> </U>%d<!U>', group_count),
    ]

    # Display the message.
    screen.popup_label(mesg, mesg.size)
  end

  # This function displays a little pop up window discussing this demo.
  def self.aboutCdkRolodex(screen)
    mesg = [
      '<C></U>About Cdk Rolodex',
      ' ',
      '</B/24>This demo was written to demonstrate the widget',
      '</B/24>available with the Cdk library. Not all of the',
      '</B/24>Cdk widget are used, but most of them have been.',
      '</B/24>I hope this little demonstration helps give you an',
      '</B/24>understanding of what the Cdk library offers.',
      ' ',
      '<C></B/24>Have fun with it.',
      ' ',
      '</B/24>Cheers,',
      '<C></B/24>Chris',
      '<C><#HL(35)>',
      '<R></B/24>March 2013',
    ]

    screen.popup_label(mesg, mesg.size)
  end

  def self.main
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)
    Slithernix::Cdk::Draw.init_color

    # Create the menu lists.
    menulist = [
      [
        '</U>File',
        '</B/5>Open   ',
        '</B/5>Save   ',
        '</B/5>Save As',
        '</B/5>Quit   ',
      ],
      [
        '</U>Groups',
        '</B/5>New   ',
        '</B/5>Open  ',
        '</B/5>Delete',
      ],
      [
        '</U>Print',
        '</B/5>Print Groups',
      ],
      [
        '</U>Help',
        '</B/5>About Rolodex     ',
        '</B/5>Rolodex Statistics',
      ],
    ]

    # Set up the sub-menu sizes and their locations
    sub_menu_size = [5, 4, 2, 3]
    menu_locations = [
      Slithernix::Cdk::LEFT, Slithernix::Cdk::LEFT,
      Slithernix::Cdk::LEFT, Slithernix::Cdk::RIGHT,
    ]

    # Create the menu.
    rolodex_menu = Slithernix::Cdk::Widget::Menu.new(
      cdkscreen,
      menulist,
      menulist.size,
      sub_menu_size,
      menu_locations,
      Slithernix::Cdk::TOP,
      Curses::A_BOLD | Curses::A_UNDERLINE,
      Curses::A_REVERSE,
    )

    # Create teh title.
    title = [
      '<C></U>Cdk Rolodex',
      '<C></B/24>Written By Chris Sauro (orignal by Mike Glover)',
    ]
    rolodex_title = Slithernix::Cdk::Widget::Label.new(
      cdkscreen,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::CENTER,
      title,
      title.size,
      false,
      false,
    )

    # This is a callback to the menu widget. It allows the user to
    # ask for help about any sub-menu item.
    help_cb = lambda do |_cdk_type, menu, _client_data, _key|
      menu_list = menu.current_title
      submenu_list = menu.current_subtitle
      selection = (menu_list * 100) + submenu_list

      # Create the help title.
      name = Slithernix::Cdk.chtype2Char(menu.sublist[menu_list][submenu_list])
      name.strip!
      mesg = [
        format('<C></R>Help<!R> </U>%s<!U>', name),
      ]
      mesg << case selection
              when 0
                '<C>This reads a new rolodex RC file.'
              when 1
                '<C>This saves the current group information in the ' \
                'default RC file.'
              when 2
                '<C>This saves the current group information in a new' \
                'RC file.'
              when 3
                '<C>This exits this program.'
              when 100
                '<C>This creates a new rolodex group.'
              when 101
                '<C>This opens a rolodex group.'
              when 102
                '<C>This deletes a rolodex group'
              when 200
                '<C>This prints out selected groups phone numbers.'
              when 300
                '<C>This gives a little history on this program.'
              when 301
                '<C>This provides information about the rolodex.'
              else
                '<C>No help defined for this menu.'
              end

      # Pop up the message.
      menu.screen.popup_label(mesg, mesg.size)

      # Redraw the submenu window.
      menu.drawSubwin
      false
    end

    # Define the help key binding
    rolodex_menu.bind(:Menu, '?', help_cb, nil)

    # Draw the CDK screen.
    cdkscreen.refresh

    # Check the value of the HOME env var.
    home = Dir.home
    if home.nil?
      # Set the value of the global rolodex DBM directory.
      @@gdbm_dir = '.rolodex'

      # Set the value of the global RC filename.
      @@grc_file = '.rolorc'
    else
      # Make sure the $HOME/.rolodex directory exists.

      # set the value of the global rolodex DBM ndirectory
      @@gdbm_dir = format('%s/.rolodex', home)

      # Set the value of the global RC filename
      @@grc_file = format('%s/.rolorc', home)
    end

    # Make the rolodex directory.
    FileUtils.mkdir_p(@@gdbm_dir, mode: 0o755)

    group_list = []

    # Open the rolodex RC file.
    group_count = Rolodex.readRCFile(@@grc_file, group_list)

    # Check the value of group_count
    if group_count.negative?
      # The RC file seems to be corrupt.
      mesg = [
        format('<C></B/16>The RC file (%s) seems to be corrupt.', @@grc_file),
        '<C></B/16>No rolodex groups were loaded.',
        '<C>Press any key to continue.',
      ]
      cdkscreen.popup_label(mesg, mesg.size)
      group_count = 0
    elsif group_count.zero?
      mesg = [
        '<C></B/24>Empty rolodex RC file. No groups loaded.',
        '<C>Press any key to continue.',
      ]
      cdkscreen.popup_label(mesg, mesg.size)
    else
      temp = if group_count == 1
               then '<C></24>There was 1 group'.dup
             else
               format('<C></24>There were %d groups', group_count)
             end
      temp << ' loaded from the RC file.'
      mesg = [
        temp,
        '<C>Press any key to continue.',
      ]
      cdkscreen.popup_label(mesg, mesg.size)
    end

    # Loop until we are done.
    loop do
      # Activate the menu.
      selection = rolodex_menu.activate([])

      # Check the return value of the selection.
      case selection
      when 0
        # Open the rolodex RC file.
        group_count = Rolodex.openNewRCFile(cdkscreen, group_list, group_count)
      when 1
        # Write out the RC file.
        ret = Rolodex.writeRCFile(
          cdkscreen, @@grc_file, group_list, group_count
        )

        # Reset the saved flag if the rc file saved ok.
        @@g_group_modified = false if ret != 0
      when 2
        # Save as.
        ret = Rolodex.writeRCFileAs(cdkscreen, group_list, group_count)

        # Reset the saved flag if the rc file saved ok.
        @@g_group_modified = false if ret != 0
      when 3
        # Has anything changed?
        if @@g_group_modified
          # Write out the RC file.
          Rolodex.writeRCFile(cdkscreen, @@grc_file, group_list, group_count)
        end

        # Remove the CDK widget pointers.
        rolodex_menu.destroy
        rolodex_title.destroy
        cdkscreen.destroy

        Slithernix::Cdk::Screen.endCDK

        exit # EXIT_SUCCESS
      when 100
        # Add a new group to the list.
        group_count = Rolodex.addRolodexGroup(cdkscreen,
                                              group_list, group_count)
      when 101
        # If there are no groups, ask them if they want to create one.
        if group_count.zero?
          buttons = [
            '<Yes>',
            '<No>',
          ]
          mesg = [
            '<C>There are no groups defined.',
            '<C>Do you want to define a new group?',
          ]

          # Add the group if they said yes.
          if cdkscreen.popup_dialog(mesg, 2, buttons, 2).zero?
            group_count = Rolodex.addRolodexGroup(
              cdkscreen, group_list, group_count
            )
          end
        else
          # Get the number of the group to open.
          group = Rolodex.pickRolodexGroup(
            cdkscreen,
            '<C></B/29>Open Rolodex Group',
            group_list,
            group_count,
          )
          # Make sure a group was picked.
          if group >= 0
            # Set the global variable @@g_current_group
            @@g_current_group = group_list[group].name.clone

            # Try to open the DBM file and read the contents.
            Rolodex.useRolodexGroup(
              cdkscreen,
              group_list[group].name,
              group_list[group].desc,
              group_list[group].dbm,
            )
          end
        end
      when 102
        # Delete the group chosen.
        group_count = Rolodex.deleteRolodexGroup(
          cdkscreen,
          group_list,
          group_count,
        )
      when 200
        # Print Phone Number Group.
        Rolodex.printGroupNumbers(cdkscreen, group_list, group_count)
      when 300
        # About Rolodex.
        Rolodex.aboutCdkRolodex(cdkscreen)
      when 301
        Rolodex.displayRolodexStats(rolodex_menu.screen, group_count)
      end
    end
  end
end

Rolodex.main
