#!/usr/bin/env ruby
require_relative 'example'

class ItemlistExample < Example
  MONTHS = 12

  def ItemlistExample.parse_opts(opts, param)
    opts.banner = 'Usage: itemlist_ex.rb [options]'

    param.x_value = Slithernix::Cdk::CENTER
    param.y_value = Slithernix::Cdk::CENTER
    param.box = true
    param.shadow = false
    param.c = false

    super(opts, param)

    opts.on('-c', 'create the data after the widget') do
      param.c = true
    end
  end

  # This program demonstrates the Cdk itemlist widget.
  #
  # Options (in addition to minimal CLI parameters):
  #      -c      create the data after the widget
  def ItemlistExample.main
    title = "<C>Pick A Month"
    label = "</U/5>Month:"
    params = parse(ARGV)

    # Get the current date and set the default month to the current month.
    start_month = Time.new.localtime.mon

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.initCDKColor

    # Create the choice list.
    info = [
        "<C></5>January",
        "<C></5>February",
        "<C></B/19>March",
        "<C></5>April",
        "<C></5>May",
        "<C></K/5>June",
        "<C></12>July",
        "<C></5>August",
        "<C></5>September",
        "<C></32>October",
        "<C></5>November",
        "<C></11>December"
    ]

    # Create the itemlist widget.
    monthlist = Slithernix::Cdk::Widget::ItemList.new(
      cdkscreen,
      params.x_value,
      params.y_value,
      title,
      label,
      params.c ? '' : info,
      params.c ? 0 : ItemlistExample::MONTHS,
      start_month,
      params.box,
      params.shadow,
    )

    # Is the widget nil?
    if monthlist.nil?
      # Clean up.
      cdkscreen.destroy
      Slithernix::Cdk::Screen.endCDK

      puts "Cannot create the itemlist box. Is the window too small?"
      exit
    end

    if params.c
      monthlist.setValues(info, ItemlistExample::MONTHS, 0)
    end

    # Activate the widget.
    choice = monthlist.activate('')

    # Check how they exited from the widget.
    if monthlist.exit_type == :ESCAPE_HIT
      mesg = [
        "<C>You hit escape. No item selected.",
        "",
        "<C>Press any key to continue."
      ]
      monthlist.screen.popupLabel(mesg, 3)
    elsif monthlist.exit_type == :NORMAL
      human_count_choice = choice + 1
      suffix = case human_count_choice
        when 1 then 'st'
        when 2 then 'nd'
        when 3 then 'rd'
        else 'th'
      end

      mesg = [
        "<C>You selected the %d%s item which is" % [human_count_choice, suffix],
        info[choice],
        "",
        "<C>Press any key to continue."
      ]

      monthlist.screen.popupLabel(mesg, 4)
    end

    # Clean up
    monthlist.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    #ExitProgram (EXIT_SUCCESS);
  end
end

ItemlistExample.main
