#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'example'

class ScrollExample < CLIExample
  @@count = 0
  def self.newLabel(prefix)
    result = format('%s%d', prefix, @@count)
    @@count += 1
    result
  end

  def self.parse_opts(opts, params)
    opts.banner = 'Usage: scroll_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = Slithernix::Cdk::CENTER
    params.y_value = Slithernix::Cdk::CENTER
    params.h_value = 10
    params.w_value = 50
    params.c = false
    params.spos = Slithernix::Cdk::RIGHT
    params.title = '<C></5>Pick a file'

    super

    opts.on('-c', 'create the data after the widget') do
      params.c = true
    end

    opts.on('-s SCROLL_POS', OptionParser::DecimalInteger,
            'location for the scrollbar') do |spos|
      params.spos = spos
    end

    opts.on('-t TITLE', String, 'title for the widget') do |title|
      params.title = title
    end
  end

  # This program demonstrates the Cdk scrolling list widget.
  #
  # Options (in addition to normal CLI parameters):
  #   -c      create the data after the widget
  #   -s SPOS location for the scrollbar
  #   -t TEXT title for the widget
  def self.main
    # Declare variables.

    params = parse(ARGV)

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.initCDKColor

    # Use the current directory list to fill the radio list
    item = []
    count = Slithernix::Cdk.getDirectoryContents('.', item)

    # Create the scrolling list.
    scroll_list = Slithernix::Cdk::Widget::Scroll.new(
      cdkscreen,
      params.x_value,
      params.y_value,
      params.spos,
      params.h_value,
      params.w_value,
      params.title,
      params.c ? nil : item,
      params.c ? 0 : count,
      true,
      Curses::A_REVERSE,
      params.box,
      params.shadow,
    )

    if scroll_list.nil?
      cdkscreen.destroyCDKScreen
      Slithernix::Cdk::Screen.endCDK

      puts 'Cannot make scrolling list.  Is the window too small?'
      exit
    end

    scroll_list.setItems(item, count, true) if params.c

    addItemCB = lambda do |_type, widget, _client_data, _input|
      widget.addItem(ScrollExample.newLabel('add'))
      widget.screen.refresh
      true
    end

    insItemCB = lambda do |_type, widget, _client_data, _input|
      widget.insertItem(ScrollExample.newLabel('insert'))
      widget.screen.refresh
      true
    end

    delItemCB = lambda do |_type, widget, _client_data, _input|
      widget.deleteItem(widget.getCurrentItem)
      widget.screen.refresh
      true
    end

    scroll_list.bind(:Scroll, 'a', addItemCB, nil)
    scroll_list.bind(:Scroll, 'i', insItemCB, nil)
    scroll_list.bind(:Scroll, 'd', delItemCB, nil)

    # Activate the scrolling list.
    selection = scroll_list.activate('')

    # Determine how the widget was exited
    case scroll_list.exit_type
    when :ESCAPE_HIT
      msg = [
        '<C>You hit escape. No file selected',
        '',
        '<C>Press any key to continue.',
      ]
    when :NORMAL
      the_item = Slithernix::Cdk.chtype2Char(scroll_list.item[selection])
      msg = [
        '<C>You selected the following file',
        format('<C>%.*s', 236, the_item), # FIXME: magic number
        '<C>Press any key to continue.'
      ]
    end

    cdkscreen.popupLabel(msg, 3)

    # Clean up.
    # CDKfreeStrings (item);
    scroll_list.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    exit
  end
end

ScrollExample.main
