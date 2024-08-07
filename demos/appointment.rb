#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'ostruct'
require_relative '../lib/slithernix/cdk'

class Appointment
  MAX_MARKERS = 2000
  APPOINTMENT_ATTRIBUTES = [
    Curses::A_BLINK,
    Curses::A_BOLD,
    Curses::A_REVERSE,
    Curses::A_UNDERLINE,
  ].freeze

  APPOINTMENT_TYPE = %i[
    BIRTHDAY
    ANNIVERSARY
    APPOINTMENT
    OTHER
  ].freeze

  # This reads a given appointment file.
  def self.read_appointment_file(filename, app_info)
    appointments = 0
    segments = 0
    lines = []

    # Read the appointment file.
    lines_read = Slithernix::Cdk.read_file(filename, lines)
    if lines_read == -1
      app_info.count = 0
      return
    end

    # Split each line up and create an appointment.
    (0...lines_read).each do |x|
      temp = lines[x].split(Slithernix::Cdk.ctrl('V').chr)
      segments =  temp.size

      # A valid line has 5 elements:
      #          Day, Month, Year, Type, Description.
      next unless segments == 5

      app_info.appointment << OpenStruct.new
      e_type = Appointment::APPOINTMENT_TYPE[temp[3].to_i]

      app_info.appointment[appointments].day = temp[0].to_i
      app_info.appointment[appointments].month = temp[1].to_i
      app_info.appointment[appointments].year = temp[2].to_i
      app_info.appointment[appointments].type = e_type
      app_info.appointment[appointments].description = temp[4]
      appointments += 1
    end

    # Keep the amount of appointments read.
    app_info.count = appointments
  end

  # This saves a given appointment file.
  def self.save_appointment_file(filename, app_info)
    # TODO: error handling
    fd = File.new(filename, 'w')

    # Start writing.
    app_info.appointment.each do |appointment|
      next unless appointment.description != ''

      fd.puts format(
        '%d%c%d%c%d%c%d%c%s',
        appointment.day,
        Slithernix::Cdk.ctrl('V').chr,
        appointment.month,
        Slithernix::Cdk.ctrl('V').chr,
        appointment.year,
        Slithernix::Cdk.ctrl('V').chr,
        Appointment::APPOINTMENT_TYPE.index(appointment.type),
        Slithernix::Cdk.ctrl('V').chr,
        appointment.description,
      )
    end

    fd.close
  end

  # This program demonstrates the Cdk calendar widget.
  def self.main
    # Get the current dates and set the default values for
    # the day/month/year values for the calendar.
    date_info = Time.now.gmtime
    day = date_info.day
    month = date_info.mon
    year = date_info.year

    title = "<C></U>CDK Appointment Book\n<C><#HL(30)>\n"

    filename = String.new

    # Check the command line for options
    opts = OptionParser.getopts('d:m:y:t:f:')
    day = opts['d'].to_i if opts['d']
    month = opts['m'].to_i if opts['m']
    year = opts['y'].to_i if opts['y']
    title = opts['t'] if opts['t']
    filename = opts['f'] if opts['f']

    # Create the appointment book filename.
    if filename == ''
      home = Dir.home
      filename = if home.nil?
                   '.appointment'
                 else
                   format('%s/.appointment', home)
                 end
    end

    appointment_info = OpenStruct.new
    appointment_info.count = 0
    appointment_info.appointment = []

    # Read the appointment book information.
    read_appointment_file(filename, appointment_info)

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.init_color

    # Create the calendar widget.
    calendar = Slithernix::Cdk::Widget::Calendar.new(
      cdkscreen,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::CENTER,
      title,
      day,
      month,
      year,
      Curses::A_NORMAL,
      Curses::A_NORMAL,
      Curses::A_NORMAL,
      Curses::A_REVERSE,
      true,
      false,
    )

    # Is the widget nil?
    if calendar.nil?
      cdkscreen.destroy
      Slithernix::Cdk::Screen.end_cdk

      puts 'Cannot create the calendar. Is the window too small?'
      exit # EXIT_FAILURE
    end

    # This adds a marker to the calendar.
    create_calendar_mark_cb = lambda do |_widget_type, calendar, info, _key|
      items = %w[
        Birthday
        Anniversary
        Appointment
        Other
      ]

      # Create the itemlist widget.
      itemlist = Slithernix::Cdk::Widget::ItemList.new(
        calendar.screen,
        Slithernix::Cdk::CENTER,
        Slithernix::Cdk::CENTER,
        '',
        'Select Appointment Type: ',
        items,
        items.size,
        0,
        true,
        false,
      )

      # Get the appointment type from the user.
      selection = itemlist.activate([])

      # They hit escape, kill the itemlist widget and leave.
      if selection == -1
        itemlist.destroy
        calendar.draw(calendar.box)
        return false
      end

      # Destroy the itemlist and set the marker.
      itemlist.destroy
      calendar.draw(calendar.box)
      marker = Appointment::APPOINTMENT_ATTRIBUTES[selection]

      # Create the entry field for the description.
      entry = Slithernix::Cdk::Widget::Entry.new(
        calendar.screen,
        Slithernix::Cdk::CENTER,
        Slithernix::Cdk::CENTER,
        '<C>Enter a description of the appointment.',
        'Description: ',
        Curses::A_NORMAL,
        '.'.ord,
        :MIXED,
        40,
        1,
        512,
        true,
        false,
      )

      # Get the description.
      description = entry.activate([])
      if description&.size&.zero?
        entry.destroy
        calendar.draw(calendar.box)
        return false
      end

      # Destroy the entry and set the marker.
      description = entry.info
      entry.destroy
      calendar.draw(calendar.box)

      # Set the marker.
      calendar.set_marker(calendar.day, calendar.month, calendar.year, marker)

      # Keep the marker.
      info.appointment << OpenStruct.new
      current = info.count

      info.appointment[current].day = calendar.day
      info.appointment[current].month = calendar.month
      info.appointment[current].year = calendar.year
      info.appointment[current].type = Appointment::APPOINTMENT_TYPE[selection]
      info.appointment[current].description = description
      info.count += 1

      # Redraw the calendar.
      calendar.draw(calendar.box)
      false
    end

    # This removes a marker from the calendar.
    remove_calendar_mark_cb = lambda do |_widget_type, calendar, info, _key|
      info.appointment.each do |appointment|
        next unless appointment.day == calendar.day &&
                    appointment.month == calendar.month &&
                    appointment.year == calendar.year

        appointment.description = String.new
        break
      end

      # Remove the marker from the calendar.
      calendar.remove_marker(calendar.day, calendar.month, calendar.year)

      # Redraw the calendar.
      calendar.draw(calendar.box)
      false
    end

    # This displays the marker(s) on the given day.
    display_calendar_mark_cb = lambda do |_widget_type, calendar, info, _key|
      found = 0
      type = String.new
      mesg = []

      # Look for the marker in the list.
      info.appointment.each do |appointment|
        # Get the day month year.
        day = appointment.day
        month = appointment.month
        year = appointment.year

        # Determine the appointment type.
        type = case appointment.type
               when :BIRTHDAY
                 'Birthday'
               when :ANNIVERSARY
                 'Anniversary'
               when :APPOINTMENT
                 'Appointment'
               else
                 'Other'
               end

        # Find the marker by the day/month/year.
        next unless day == calendar.day && month == calendar.month &&
                    year == calendar.year && appointment.description != ''

        # Create the message for the label widget.
        mesg << (format('<C>Appointment Date: %02d/%02d/%d', day, month, year))
        mesg << ' '
        mesg << '<C><#HL(35)>'
        mesg << (format(' Appointment Type: %s', type))
        mesg << ' Description     :'
        mesg << (format('    %s', appointment.description))
        mesg << '<C><#HL(35)>'
        mesg << ' '
        mesg << '<C>Press space to continue.'

        found = 1
        break
      end

      # If we didn't find the marker, create a different message.
      if found.zero?
        mesg << format(
          '<C>There is no appointment for %02d/%02d/%d',
          calendar.day,
          calendar.month,
          calendar.year
        )
        mesg << '<C><#HL(30)>'
        mesg << '<C>Press space to continue.'
      end

      # Create the label widget
      label = Slithernix::Cdk::Widget::Label.new(
        calendar.screen,
        Slithernix::Cdk::CENTER,
        Slithernix::Cdk::CENTER,
        mesg,
        mesg.size,
        true,
        false
      )

      label.draw(label.box)
      label.wait(' ')
      label.destroy

      # Redraw the calendar
      calendar.draw(calendar.box)
      false
    end

    # This allows the user to accelerate to a given date.
    accelerate_to_date_cb = lambda do |_widget_type, _widget, _client_data, _key|
      false
    end

    # Create a key binding to mark days on the calendar.
    calendar.bind(:Calendar, 'm', create_calendar_mark_cb, appointment_info)
    calendar.bind(:Calendar, 'M', create_calendar_mark_cb, appointment_info)
    calendar.bind(:Calendar, 'r', remove_calendar_mark_cb, appointment_info)
    calendar.bind(:Calendar, 'R', remove_calendar_mark_cb, appointment_info)
    calendar.bind(:Calendar, '?', display_calendar_mark_cb, appointment_info)
    calendar.bind(:Calendar, 'j', accelerate_to_date_cb, appointment_info)
    calendar.bind(:Calendar, 'J', accelerate_to_date_cb, appointment_info)

    # Set all the appointments read from the file.
    appointment_info.appointment.each do |appointment|
      marker = Appointment::APPOINTMENT_ATTRIBUTES[
          Appointment::APPOINTMENT_TYPE.index(appointment.type)
      ]

      calendar.set_marker(
        appointment.day,
        appointment.month,
        appointment.year,
        marker,
      )
    end

    calendar.draw(calendar.box)
    calendar.activate([])

    Appointment.save_appointment_file(filename, appointment_info)

    calendar.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.end_cdk
  end
end

Appointment.main
