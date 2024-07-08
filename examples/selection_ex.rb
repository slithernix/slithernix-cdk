#!/usr/bin/env ruby
# frozen_string_literal: true

require 'etc'
require_relative 'example'

class SelectionExample < CLIExample
  def self.parse_opts(opts, params)
    opts.banner = 'Usage: selection_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false

    params.header = String.new
    params.footer = String.new

    params.x_value = Slithernix::Cdk::CENTER
    params.y_value = nil
    params.h_value = 10
    params.w_value = 50
    params.box = true
    params.c = false
    params.spos = Slithernix::Cdk::RIGHT
    params.title = '<C></5>Pick one or more accounts.'
    params.shadow = false

    super

    opts.on('-c', 'create the data after the widget') do
      params.c = true
    end

    opts.on('-f TEXT', String, 'title for a footer label') do |footer|
      params.footer = footer
    end

    opts.on('-h TEXT', String, 'title for a header label') do |header|
      params.header = header
    end

    opts.on('-s SPOS', OptionParser::DecimalInteger,
            'location for the scrollbar') do |spos|
      params.spos = spos
    end

    opts.on('-t TEXT', String, 'title for the widget') do |title|
      params.title = title
    end
  end

  # This program demonstrates the Cdk selection widget.
  #
  # Options (in addition to normal CLI parameters):
  #   -c      create the data after the widget
  #   -f TEXT title for a footer label
  #   -h TEXT title for a header label
  #   -s SPOS location for the scrollbar
  #   -t TEXT title for the widget
  def self.main
    choices = [
      '   ',
      '-->'
    ]

    item = []
    params = parse(ARGV)

    # Use the account names to create a list.
    until (ent = Etc.getpwent).nil?
      item << ent.name
    end
    Etc.endpwent

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.init_color

    if params.header != ''
      list = [params.header]
      header = Slithernix::Cdk::Widget::Label.new(
        cdkscreen,
        params.x_value,
        params.y_value.nil? ? Slithernix::Cdk::TOP : params.y_value,
        list,
        1,
        params.box,
        !params.shadow,
      )
      header&.activate([])
    end

    if params.footer != ''
      list = [params.footer]
      footer = Slithernix::Cdk::Widget::Label.new(
        cdkscreen,
        params.x_value,
        params.y_value.nil? ? Slithernix::Cdk::BOTTOM : params.y_value,
        list,
        1,
        params.box,
        !params.shadow,
      )
      footer&.activate([])
    end

    # Create the selection list.
    selection = Slithernix::Cdk::Widget::Selection.new(
      cdkscreen,
      params.x_value,
      params.y_value.nil? ? Slithernix::Cdk::CENTER : params.y_value,
      params.spos,
      params.h_value,
      params.w_value,
      params.title,
      params.c ? [] : item,
      params.c ? 0 : item.size,
      choices,
      2,
      Curses::A_REVERSE,
      params.box,
      params.shadow
    )

    if selection.nil?
      cdkscreen.destroyCDKScreen
      Slithernix::Cdk::Screen.endCDK

      puts 'Cannot make selection list.  Is the window too small?'
      exit
    end

    selection.setItems(item, item.size) if params.c

    # Activate the selection list.
    selection.activate([])

    # Check the exit status of the widget
    if selection.exit_type == :ESCAPE_HIT
      mesg = [
        '<C>You hit escape. No item selected',
        '',
        '<C>Press any key to continue.'
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif selection.exit_type == :NORMAL
      mesg = ['<C>Here are the accounts you selected.']
      (0...item.size).each do |x|
        if selection.selections[x] == 1
          mesg << (format('<C></5>%.*s', 236, item[x])) # FIXME: magic number
        end
      end
      cdkscreen.popupLabel(mesg, mesg.size)
    else
      mesg = ['<C>Unknown failure.']
      cdkscreen.popupLabel(mesg, mesg.size)
    end

    # Clean up.
    selection.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    exit
  end
end

SelectionExample.main
