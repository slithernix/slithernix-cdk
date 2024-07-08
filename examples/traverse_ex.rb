#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'example'

class TraverseExample < Example
  MY_MAX = 3
  YES_NO = %w[Yes NO].freeze
  MONTHS = %w[Jan Feb Mar Apr May Jun Jul Aug Sep
              Oct Nov Dec].freeze
  CHOICES = ['[ ]', '[*]'].freeze
  # Exercise all widget except
  #     CDKMENU
  #     CDKTRAVERSE
  # The names in parentheses do not accept input, so they will never have
  # focus for traversal.  The names with leading '*' have some limitation
  # that makes them not useful in traversal.
  MENU_TABLE = [
    ['(CDKGraph)',      :Graph], # no traversal (not active)
    ['(CDKHistogram)',  :Histogram], # no traversal (not active)
    ['(CDKLabel)',      :Label], # no traversal (not active)
    ['(CDKMarquee)',    :Marquee], # hangs (leaves trash)
    ['*CDKViewer',      :Viewer], # traversal out-only on OK
    ['AlphaList',       :AlphaList],
    ['Button',          :Button],
    ['ButtinBox',       :ButtonBox],
    ['Calendar',        :Calendar],
    ['Dialog',          :Dialog],
    ['DScale',          :DScale],
    ['Entry',           :Entry],
    ['FScale',          :FScale],
    ['FSelect',         :FSelect],
    ['FSlider',         :FSlider],
    ['ItemList',        :ItemList],
    ['Matrix',          :Matrix],
    ['MEntry',          :MEntry],
    ['Radio',           :Radio],
    ['Scale',           :Scale],
    ['Scroll',          :Scroll],
    ['Selection',       :Selection],
    ['Slider',          :Slider],
    ['SWindow',         :SWindow],
    ['Template',        :Template],
    ['UScale',          :UScale],
    ['USlider',         :USlider],
  ].freeze
  @@all_widgets = [nil] * MY_MAX

  def self.make_alphalist(cdkscreen, x, y)
    Slithernix::Cdk::AlphaList.new(cdkscreen, x, y, 10, 15, 'AlphaList', '->',
                                   TraverseExample::MONTHS, TraverseExample::MONTHS.size,
                                   '_'.ord, Curses::A_REVERSE, true, false)
  end

  def self.make_button(cdkscreen, x, y)
    Slithernix::Cdk::BUTTON.new(cdkscreen, x, y, 'A Button!', nil, true, false)
  end

  def self.make_buttonbox(cdkscreen, x, y)
    Slithernix::Cdk::Widget::ButtonBox.new(cdkscreen, x, y, 10, 16, 'ButtonBox', 6, 2,
                                           TraverseExample::MONTHS, TraverseExample::MONTHS.size,
                                           Curses::A_REVERSE, true, false)
  end

  def self.make_calendar(cdkscreen, x, y)
    Slithernix::Cdk::Widget::Calendar.new(cdkscreen, x, y, 'Calendar', 25, 1, 2000,
                                          Curses.color_pair(16) | Curses::A_BOLD,
                                          Curses.color_pair(24) | Curses::A_BOLD,
                                          Curses.color_pair(32) | Curses::A_BOLD,
                                          Curses.color_pair(40) | Curses::A_REVERSE,
                                          true, false)
  end

  def self.make_dialog(cdkscreen, x, y)
    mesg = [
      'This is a simple dialog box',
      'Is it simple enough?',
    ]

    Slithernix::Cdk::Widget::Dialog.new(cdkscreen, x, y, mesg, mesg.size,
                                        TraverseExample::YES_NO, TraverseExample::YES_NO.size,
                                        Curses.color_pair(2) | Curses::A_REVERSE,
                                        true, true, false)
  end

  def self.make_dscale(cdkscreen, x, y)
    Slithernix::Cdk::DScale.new(cdkscreen, x, y, 'DScale', 'Value',
                                Curses::A_NORMAL, 15, 0.0, 0.0, 100.0, 1.0, (1.0 * 2.0), 1,
                                true, false)
  end

  def self.make_entry(cdkscreen, x, y)
    Slithernix::Cdk::Widget::Entry.new(cdkscreen, x, y, '', 'Entry:', Curses::A_NORMAL,
                                       '.'.ord, :MIXED, 40, 0, 256, true, false)
  end

  def self.make_fscale(cdkscreen, x, y)
    Slithernix::Cdk::Widget::FScale.new(cdkscreen, x, y, 'FScale', 'Value',
                                        Curses::A_NORMAL, 15, 0.0, 0.0, 100.0, 1.0, (1.0 * 2.0), 1,
                                        true, false)
  end

  def self.make_fslider(cdkscreen, x, y)
    low = -32.0
    high = 64.0
    inc = 0.1
    Slithernix::Cdk::Widget::FSlider.new(cdkscreen, x, y, 'FSlider', 'Label',
                                         Curses::A_REVERSE | Curses.color_pair(29) | ' '.ord,
                                         20, low, low, high, inc, (inc * 2), 3, true, false)
  end

  def self.make_fselect(cdkscreen, x, y)
    Slithernix::Cdk::Widget::FSelect.new(cdkscreen, x, y, 15, 25, 'FSelect', '->',
                                         Curses::A_NORMAL, '_'.ord, Curses::A_REVERSE, '</5>', '</48>',
                                         '</N>', '</N>', true, false)
  end

  def self.make_graph(cdkscreen, x, y)
    values = [10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
    graph_chars = '0123456789'
    widget = Slithernix::Cdk::Widget::Graph.new(cdkscreen, x, y, 10, 25, 'title', 'X-axis',
                                                'Y-axis')
    widget.set(values, values.size, graph_chars, true, :PLOT)
    widget
  end

  def self.make_histogram(cdkscreen, x, y)
    widget = Slithernix::Cdk::Widget::Histogram.new(cdkscreen, x, y, 1, 20, Slithernix::Cdk::HORIZONTAL,
                                                    'Histogram', true, false)
    widget.set(:PERCENT, Slithernix::Cdk::CENTER, Curses::A_BOLD, 0, 10, 6,
               ' '.ord | Curses::A_REVERSE, true)
    widget
  end

  def self.make_itemlist(cdkscreen, x, y)
    Slithernix::Cdk::Widget::ItemList.new(cdkscreen, x, y, '', 'Month',
                                          TraverseExample::MONTHS, TraverseExample::MONTHS.size, 1, true, false)
  end

  def self.make_label(cdkscreen, x, y)
    mesg = [
      'This is a simple label.',
      'Is it simple enough?',
    ]
    Slithernix::Cdk::Widget::Label.new(cdkscreen, x, y, mesg, mesg.size, true,
                                       true)
  end

  def self.make_marquee(cdkscreen, x, y)
    widget = Slithernix::Cdk::Widget::Marquee.new(cdkscreen, x, y, 30, true,
                                                  true)
    widget.activate('This is a message', 5, 3, true)
    widget.destroy
    nil
  end

  def self.make_matrix(cdkscreen, x, y)
    numrows = 8
    numcols = 5
    coltitle = []
    cols = numcols
    colwidth = []
    coltypes = []
    maxwidth = 0
    rows = numrows
    vcols = 3
    vrows = 3

    rowtitle = (0..numrows).map do |n|
      format('row%d', n)
    end

    (0..numcols).each do |n|
      coltitle << (format('col%d', n))
      colwidth << coltitle[n].size
      coltypes << :UCHAR
      maxwidth = colwidth[n] if colwidth[n] > maxwidth
    end

    Slithernix::Cdk::Widget::Matrix.new(cdkscreen, x, y, rows, cols, vrows, vcols,
                                        'Matrix', rowtitle, coltitle, colwidth, coltypes, -1, -1, '.'.ord,
                                        Slithernix::Cdk::COL, true, true, false)
  end

  def self.make_mentry(cdkscreen, x, y)
    Slithernix::Cdk::Widget::MEntry.new(cdkscreen, x, y, 'MEntry', 'Label',
                                        Curses::A_BOLD, '.', :MIXED, 20, 5, 20, 0, true, false)
  end

  def self.make_radio(cdkscreen, x, y)
    Slithernix::Cdk::Widget::Radio.new(cdkscreen, x, y, Slithernix::Cdk::RIGHT, 10, 20, 'Radio',
                                       TraverseExample::MONTHS, TraverseExample::MONTHS.size,
                                       '#'.ord | Curses::A_REVERSE, 1, Curses::A_REVERSE, true, false)
  end

  def self.make_scale(cdkscreen, x, y)
    low = 2
    high = 25
    inc = 2
    Slithernix::Cdk::Widget::Scale.new(cdkscreen, x, y, 'Scale', 'Label',
                                       Curses::A_NORMAL, 5, low, low, high, inc, (inc * 2), true, false)
  end

  def self.make_scroll(cdkscreen, x, y)
    Slithernix::Cdk::Widget::Scroll.new(cdkscreen, x, y, Slithernix::Cdk::RIGHT, 10, 20, 'Scroll',
                                        TraverseExample::MONTHS, TraverseExample::MONTHS.size,
                                        true, Curses::A_REVERSE, true, false)
  end

  def self.make_slider(cdkscreen, x, y)
    low = 2
    high = 25
    inc = 1
    Slithernix::Cdk::Widget::Slider.new(cdkscreen, x, y, 'Slider', 'Label',
                                        Curses::A_REVERSE | Curses.color_pair(29) | ' '.ord,
                                        20, low, low, high, inc, (inc * 2), true, false)
  end

  def self.make_selection(cdkscreen, x, y)
    Slithernix::Cdk::Widget::Selection.new(cdkscreen, x, y, Slithernix::Cdk::NONE, 8, 20,
                                           'Selection', TraverseExample::MONTHS, TraverseExample::MONTHS.size,
                                           TraverseExample::CHOICES, TraverseExample::CHOICES.size,
                                           Curses::A_REVERSE, true, false)
  end

  def self.make_swindow(cdkscreen, x, y)
    widget = Slithernix::Cdk::Widget::SWindow.new(cdkscreen, x, y, 6, 25,
                                                  'SWindow', 100, true, false)
    (0...30).each do |n|
      widget.add(format('Line %d', n), Slithernix::Cdk::BOTTOM)
    end
    widget.activate([])
    widget
  end

  def self.make_template(cdkscreen, x, y)
    overlay = '</B/6>(___)<!6> </5>___-____'
    plate = '(###) ###-####'
    widget = Slithernix::Cdk::Widget::Template.new(cdkscreen, x, y, 'Template', 'Label',
                                                   plate, overlay, true, false)
    widget.activate([])
    widget
  end

  def self.make_uscale(cdkscreen, x, y)
    low = 0
    high = 65_535
    inc = 1
    Slithernix::Cdk::UScale.new(cdkscreen, x, y, 'UScale', 'Label',
                                Curses::A_NORMAL, 5, low, low, high, inc, (inc * 32), true, false)
  end

  def self.make_uslider(cdkscreen, x, y)
    low = 0
    high = 65_535
    inc = 1
    Slithernix::Cdk::Widget::USlider.new(cdkscreen, x, y, 'USlider', 'Label',
                                         Curses::A_REVERSE | Curses.color_pair(29) | ' '.ord, 20,
                                         low, low, high, inc, (inc * 32), true, false)
  end

  def self.make_viewer(cdkscreen, x, y)
    button = ['Ok']
    widget = Slithernix::Cdk::Widget::Viewer.new(cdkscreen, x, y, 10, 20, button, 1,
                                                 Curses::A_REVERSE, true, false)

    widget.set('Viewer', TraverseExample::MONTHS, TraverseExample::MONTHS.size,
               Curses::A_REVERSE, false, true, true)
    widget.activate([])
    widget
  end

  def self.rebind_esc(widg)
    widg.bind(widg.widget_type, Slithernix::Cdk::KEY_F(1), :getc,
              Slithernix::Cdk::KEY_ESC)
  end

  def self.make_any(cdkscreen, menu, type)
    func = nil
    # setup positions, staggered a little
    case menu
    when 0
      x = Slithernix::Cdk::LEFT
      y = 2
    when 1
      x = Slithernix::Cdk::CENTER
      y = 4
    when 2
      x = Slithernix::Cdk::RIGHT
      y = 2
    else
      Slithernix::Cdk.Beep
      return
    end

    # Find the function to make a widget of the given type
    case type
    when :AlphaList
      func = :make_alphalist
    when :Button
      func = :make_button
    when :ButtonBox
      func = :make_buttonbox
    when :Calendar
      func = :make_calendar
    when :Dialog
      func = :make_dialog
    when :DScale
      func = :make_dscale
    when :Entry
      func = :make_entry
    when :FScale
      func = :make_fscale
    when :FSelect
      func = :make_fselect
    when :FSlider
      func = :make_fslider
    when :Graph
      func = :make_graph
    when :Histogram
      func = :make_histogram
    when :ItemList
      func = :make_itemlist
    when :Label
      func = :make_label
    when :Marquee
      func = :make_marquee
    when :Matrix
      func = :make_matrix
    when :MEntry
      func = :make_mentry
    when :Radio
      func = :make_radio
    when :Scale
      func = :make_scale
    when :Scroll
      func = :make_scroll
    when :Selection
      func = :make_selection
    when :Slider
      func = :make_slider
    when :SWindow
      func = :make_swindow
    when :Template
      func = :make_template
    when :UScale
      func = :make_uscale
    when :USlider
      func = :make_uslider
    when :Viewer
      func = :make_viewer
    when :Menu, :TRAVERSE, :NULL
      Slithernix::Cdk.Beep
      return
    end

    # erase the old widget
    unless (prior = @@all_widgets[menu]).nil?
      prior.erase
      prior.destroy
      @@all_widgets[menu] = nil
    end

    # Create the new widget
    if func.nil?
      Slithernix::Cdk.Beep
    else
      widget = send(func, cdkscreen, x, y)
      if widget.nil?
        Curses.flash
      else
        @@all_widgets[menu] = widget
        rebind_esc(widget)
      end
    end
  end

  # Whenever we get a menu selection, create the selected widget.
  def self.preHandler(_cdktype, widget, _client_data, input)
    screen = nil

    case input
    when Curses::KEY_ENTER, Slithernix::Cdk::KEY_RETURN
      mtmp = []
      stmp = []
      widget.getCurrentItem(mtmp, stmp)
      mp = mtmp[0]
      sp = stmp[0]

      screen = widget.screen
      window = screen.window

      window.mvwprintw(window.getmaxy - 1, 0, 'selection %d/%d', mp, sp)
      Curses.clrtoeol
      Curses.refresh
      if sp >= 0 && sp < TraverseExample::MENU_TABLE.size
        make_any(screen, mp, TraverseExample::MENU_TABLE[sp][1])
      end
    end
    1
  end

  # This demonstrates the Cdk widget-traversal
  def self.main
    menulist = [['Left'], ['Center'], ['Right']]
    submenusize = [TraverseExample::MENU_TABLE.size + 1] * 3
    menuloc = [
      Slithernix::Cdk::LEFT,
      Slithernix::Cdk::LEFT,
      Slithernix::Cdk::RIGHT,
    ]

    (0...TraverseExample::MY_MAX).each do |j|
      (0...TraverseExample::MENU_TABLE.size).each do |k|
        menulist[j] << TraverseExample::MENU_TABLE[k][0]
      end
    end

    # Create the curses window.
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Start CDK colours.
    Slithernix::Cdk::Draw.init_color

    menu = Slithernix::Cdk::Widget::Menu.new(
      cdkscreen,
      menulist,
      TraverseExample::MY_MAX,
      submenusize,
      menuloc,
      Slithernix::Cdk::TOP,
      Curses::A_UNDERLINE,
      Curses::A_REVERSE,
    )

    if menu.nil?
      cdkscreen.destroy
      Slithernix::Cdk::Screen.end_cdk

      puts '? Cannot create menus'
      exit # EXIT_FAILURE
    end
    TraverseExample.rebind_esc(menu)

    pre_handler = lambda do |cdktype, widget, client_data, input|
      TraverseExample.preHandler(cdktype, widget, client_data, input)
    end

    menu.set_pre_process(pre_handler, nil)

    # Set up the initial display
    TraverseExample.make_any(cdkscreen, 0, :Entry)
    if TraverseExample::MY_MAX > 1
      TraverseExample.make_any(cdkscreen, 1, :ItemList)
    end
    if TraverseExample::MY_MAX > 2
      TraverseExample.make_any(cdkscreen, 2, :Selection)
    end

    # Draw the screen
    cdkscreen.refresh

    # Traverse the screen
    Slithernix::Cdk::Traverse.traverse_screen(cdkscreen)

    mesg = [
      'Done',
      '',
      '<C>Press any key to continue'
    ]
    cdkscreen.popup_label(mesg, 3)

    # clean up and exit
    (0...TraverseExample::MY_MAX).each do |j|
      if j < @@all_widgets.size && !(@@all_widgets[j]).nil?
        @@all_widgets[j].destroy
      end
    end
    menu.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.end_cdk

    exit # EXIT_SUCCESS
  end
end

TraverseExample.main
