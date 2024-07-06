#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'example'

class ViewerExample < CLIExample
  def self.parse_opts(opts, params)
    opts.banner = 'Usage: viewer_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = Slithernix::Cdk::CENTER
    params.y_value = Slithernix::Cdk::CENTER
    params.h_value = 20
    params.w_value = nil
    params.filename = ''
    params.directory = '.'
    params.interp = false
    params.link = false

    super

    opts.on('-f FILENAME', String, 'Filename to open') do |f|
      params.filename = f
    end

    opts.on('-d DIR', String, 'Default directory') do |d|
      params.directory = d
    end

    opts.on('-i', String, 'Interpret embedded markup') do
      params.interp = true
    end

    opts.on('-l', String, 'Load file via embedded link') do
      params.link = true
    end
  end

  # Demonstrate a scrolling-window.
  def self.main
    title = "<C>Pick\n<C>A\n<C>File"
    label = 'File: '
    button = [
      '</5><OK><!5>',
      '</5><Cancel><!5>',
    ]

    # Declare variables.
    params = parse(ARGV)
    if params.w_value.nil?
      params.f_width = 65
      params.v_width = -2
    else
      params.f_width = params.w_value
      params.v_width = params.w_value
    end

    # Start curses
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Start CDK colors.
    Slithernix::Cdk::Draw.initCDKColor

    f_select = nil
    if params.filename == ''
      f_select = Slithernix::Cdk::Widget::FSelect.new(
        cdkscreen,
        params.x_value,
        params.y_value,
        params.h_value,
        params.f_width,
        title,
        label,
        Curses::A_NORMAL,
        '_',
        Curses::A_REVERSE,
        '</5>',
        '</48>',
        '</N>',
        '</N',
        params.box,
        params.shadow,
      )

      if f_select.nil?
        cdkscreen.destroy
        Slithernix::Cdk::Screen.endCDK

        warn 'Cannot create fselect-widget'
        exit
      end

      # Set the starting directory. This is not necessary because when
      # the file selector starts it uses the present directory as a default.
      f_select.set(
        params.directory,
        Curses::A_NORMAL,
        '.',
        Curses::A_REVERSE,
        '</5>',
        '</48>',
        '</N>',
        '</N>',
        @box
      )

      # Activate the file selector.
      params.filename = f_select.activate([])

      # Check how the person exited from the widget.
      if f_select.exit_type == :ESCAPE_HIT
        # Pop up a message for the user.
        mesg = [
          '<C>Escape hit. No file selected.',
          '',
          '<C>Press any key to continue.',
        ]
        cdkscreen.popupLabel(mesg, 3)

        f_select.destroy
        cdkscreen.destroy
        Slithernix::Cdk::Screen.endCDK
        exit
      end
    end

    # Create the file viewer to view the file selected.
    example = Slithernix::Cdk::Widget::Viewer.new(
      cdkscreen,
      params.x_value,
      params.y_value,
      params.h_value,
      params.v_width,
      button,
      2,
      Curses::A_REVERSE,
      params.box,
      params.shadow
    )

    # Could we create the viewer widget?
    if example.nil?
      # Exit CDK.
      cdkscreen.destroy
      Slithernix::Cdk::Screen.endCDK

      puts 'Cannot create the viewer. Is the window too small?'
      exit
    end

    info = []
    lines = -1
    # Load up the scrolling window.
    if params.link
      info = ['<F=%s>' % params.filename]
      params.interp = true
    else
      example.set('reading...', 0, 0, Curses::A_REVERSE, true, true, true)
      # Open the file and read the contents.
      lines = Slithernix::Cdk.readFile(params.filename, info)
      if lines == -1
        Slithernix::Cdk::Screen.endCDK
        puts format('Could not open "%s"', params.filename)
        exit
      end
    end

    # Set up the viewer title and the contents to the widget.
    v_title = format('<C></B/21>Filename:<!21></22>%20s<!22!B>',
                     params.filename)
    example.set(
      v_title,
      info,
      lines,
      Curses::A_REVERSE,
      params.interp,
      true,
      true,
    )

    # Destroy the file selector widget.
    f_select&.destroy

    # Activate the viewer widget.
    selected = example.activate([])

    # Check how the person exited from the widget.
    case example.exit_type
    when :ESCAPE_HIT
      mesg = [
        '<C>Escape hit. No Button selected..',
        '',
        '<C>Press any key to continue.',
      ]
    when :NORMAL
      mesg = [
        format('<C>You selected button %d', selected),
        '',
        '<C>Press any key to continue.'
      ]
    end

    cdkscreen.popupLabel(mesg, 3)
    example.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    exit
  end
end

ViewerExample.main
