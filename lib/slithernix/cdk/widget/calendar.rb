require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class Calendar < Slithernix::Cdk::Widget
        attr_accessor :week_base
        attr_reader :day, :month, :year

        MONTHS_OF_THE_YEAR = %w[
          NULL
          January
          February
          March
          April
          May
          June
          July
          August
          September
          October
          November
          December
        ]

        DAYS_OF_THE_MONTH = [
          -1,
          31,
          28,
          31,
          30,
          31,
          30,
          31,
          31,
          30,
          31,
          30,
          31,
        ]

        MAX_DAYS = 32
        MAX_MONTHS = 13
        MAX_YEARS = 140

        CALENDAR_LIMIT = MAX_DAYS * MAX_MONTHS * MAX_YEARS

        def self.CALENDAR_INDEX(d, m, y)
          (((y * Slithernix::Cdk::Widget::Calendar::MAX_MONTHS) + m) * Slithernix::Cdk::Widget::Calendar::MAX_DAYS) + d
        end

        def setCalendarCell(d, m, y, value)
          @marker[Slithernix::Cdk::Widget::Calendar.CALENDAR_INDEX(d, m, y)] =
            value
        end

        def getCalendarCell(d, m, y)
          @marker[Slithernix::Cdk::Widget::Calendar.CALENDAR_INDEX(d, m, y)]
        end

        def initialize(cdkscreen, xplace, yplace, title, day, month, year,
                       day_attrib, month_attrib, year_attrib, highlight, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          box_width = 24
          box_height = 11
          dayname = 'Su Mo Tu We Th Fr Sa '
          bindings = {
            'T' => Curses::KEY_HOME,
            't' => Curses::KEY_HOME,
            'n' => Curses::KEY_NPAGE,
            Slithernix::Cdk::FORCHAR => Curses::KEY_NPAGE,
            'p' => Curses::KEY_PPAGE,
            Slithernix::Cdk::BACKCHAR => Curses::KEY_PPAGE
          }

          setBox(box)

          box_width = setTitle(title, box_width)
          box_height += @title_lines

          # Make sure we didn't extend beyond the dimensions of the window.
          box_width = [box_width, parent_width].min
          box_height = [box_height, parent_height].min

          # Rejustify the x and y positions if we need to.
          xtmp = [xplace]
          ytmp = [yplace]
          Slithernix::Cdk.alignxy(cdkscreen.window, xtmp, ytmp, box_width,
                                  box_height)
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Create the calendar window.
          @win = Curses::Window.new(box_height, box_width, ypos, xpos)

          # Is the window nil?
          if @win.nil?
            destroy
            return nil
          end
          @win.keypad(true)

          # Set some variables.
          @x_offset = (box_width - 20) / 2
          @field_width = box_width - (2 * (1 + @border_size))

          # Set months and day names
          @month_name = Slithernix::Cdk::Widget::Calendar::MONTHS_OF_THE_YEAR.clone
          @day_name = dayname

          # Set the rest of the widget values.
          @screen = cdkscreen
          @parent = cdkscreen.window
          @shadow_win = nil
          @xpos = xpos
          @ypos = ypos
          @box_width = box_width
          @box_height = box_height
          @day = day
          @month = month
          @year = year
          @day_attrib = day_attrib
          @month_attrib = month_attrib
          @year_attrib = year_attrib
          @highlight = highlight
          @width = box_width
          @accepts_focus = true
          @input_window = @win
          @week_base = 0
          @shadow = shadow
          @label_win = @win.subwin(1, @field_width,
                                   ypos + @title_lines + 1, xpos + 1 + @border_size)
          if @label_win.nil?
            destroy
            return nil
          end

          @field_win = @win.subwin(7, 20,
                                   ypos + @title_lines + 3, xpos + @x_offset)
          if @field_win.nil?
            destroy
            return nil
          end
          setBox(box)

          @marker = [0] * Slithernix::Cdk::Widget::Calendar::CALENDAR_LIMIT

          # If the day/month/year values were 0, then use today's date.
          if @day.zero? && @month.zero? && @year.zero?
            date_info = Time.new.gmtime
            @day = date_info.day
            @month = date_info.month
            @year = date_info
          end

          # Verify the dates provided.
          verifyCalendarDate

          # Determine which day the month starts on.
          @week_day = Slithernix::Cdk::Widget::Calendar.getMonthStartWeekday(
            @year, @month
          )

          # If a shadow was requested, then create the shadow window.
          if shadow
            @shadow_win = Curses::Window.new(box_height, box_width,
                                             ypos + 1, xpos + 1)
          end

          # Setup the key bindings.
          bindings.each do |from, to|
            bind(:Calendar, from, :getc, to)
          end

          cdkscreen.register(:Calendar, self)
        end

        # This function lets the user play with this widget.
        def activate(actions)
          ret = -1
          draw(@box)

          if actions.nil? || actions.size.zero?
            while true
              input = getch([])

              # Inject the character into the widget.
              ret = inject(input)
              return ret if @exit_type != :EARLY_EXIT
            end
          else
            # Inject each character one at a time.
            actions.each do |action|
              ret = inject(action)
              return ret if @exit_type != :EARLY_EXIT
            end
          end
          ret
        end

        # This injects a single character into the widget.
        def inject(input)
          # Declare local variables
          pp_return = 1
          ret = -1
          complete = false

          # Set the exit type
          setExitType(0)

          # Refresh the widget field.
          drawField

          # Check if there is a pre-process function to be called.
          unless @pre_process_func.nil?
            pp_return = @pre_process_func.call(:Calendar, self,
                                               @pre_process_data, input)
          end

          # Should we continue?
          if pp_return != 0
            # Check a predefined binding
            if checkBind(:Calendar, input)
              checkEarlyExit
              complete = true
            else
              case input
              when Curses::KEY_UP
                decrementCalendarDay(7)
              when Curses::KEY_DOWN
                incrementCalendarDay(7)
              when Curses::KEY_LEFT
                decrementCalendarDay(1)
              when Curses::KEY_RIGHT
                incrementCalendarDay(1)
              when Curses::KEY_NPAGE
                incrementCalendarMonth(1)
              when Curses::KEY_PPAGE
                decrementCalendarMonth(1)
              when 'N'
                incrementCalendarMonth(6)
              when 'P'
                decrementCalendarMonth(6)
              when '-'
                decrementCalendarYear(1)
              when '+'
                incrementCalendarYear(1)
              when Curses::KEY_HOME
                setDate(-1, -1, -1)
              when Slithernix::Cdk::KEY_ESC
                setExitType(input)
                complete = true
              when Curses::Error
                setExitType(input)
                complete = true
              when Slithernix::Cdk::KEY_TAB, Slithernix::Cdk::KEY_RETURN, Curses::KEY_ENTER
                setExitType(input)
                ret = getCurrentTime
                complete = true
              when Slithernix::Cdk::REFRESH
                @screen.erase
                @screen.refresh
              end
            end

            # Should we do a post-process?
            if !complete and @post_process_func
              @post_process_func.call(:Calendar, self, @post_process_data,
                                      input)
            end
          end

          setExitType(0) unless complete

          @result_data = ret
          ret
        end

        # This moves the calendar field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@win, @field_win, @label_win, @shadow_win]
          move_specific(xplace, yplace, relative, refresh_flag,
                        windows, [])
        end

        # This draws the calendar widget.
        def draw(box)
          header_len = @day_name.size
          col_len = (6 + header_len) / 7

          # Is there a shadow?
          Slithernix::Cdk::Draw.drawShadow(@shadow_win) unless @shadow_win.nil?

          # Box the widget if asked.
          Slithernix::Cdk::Draw.drawObjBox(@win, self) if box

          drawTitle(@win)

          # Draw in the day-of-the-week header.
          (0...7).each do |col|
            src = col_len * ((col + (@week_base % 7)) % 7)
            dst = col_len * col
            Slithernix::Cdk::Draw.writeChar(@win, @x_offset + dst, @title_lines + 2,
                                            @day_name[src..-1], Slithernix::Cdk::HORIZONTAL, 0, col_len)
          end

          @win.refresh
          drawField
        end

        # This draws the month field.
        def drawField
          month_name = @month_name[@month]
          month_length = Slithernix::Cdk::Widget::Calendar.getMonthLength(
            @year, @month
          )
          year_index = Slithernix::Cdk::Widget::Calendar.YEAR2INDEX(@year)
          year_len = 0
          save_y = -1
          save_x = -1

          day = (1 - @week_day + (@week_base % 7))
          day -= 7 if day.positive?

          (1..6).each do |row|
            (0...7).each do |col|
              if day >= 1 && day <= month_length
                xpos = col * 3
                ypos = row

                marker = @day_attrib
                temp = '%02d' % day

                if @day == day
                  marker = @highlight
                  save_y = ypos + @field_win.begy - @input_window.begy
                  save_x = 1
                else
                  marker |= getMarker(day, @month, year_index)
                end
                Slithernix::Cdk::Draw.writeCharAttrib(@field_win, xpos, ypos, temp, marker,
                                                      Slithernix::Cdk::HORIZONTAL, 0, 2)
              end
              day += 1
            end
          end
          @field_win.refresh

          # Draw the month in.
          if @label_win
            temp = format('%s %d,', month_name, @day)
            Slithernix::Cdk::Draw.writeChar(
              @label_win,
              0,
              0,
              temp,
              Slithernix::Cdk::HORIZONTAL,
              0,
              temp.size,
            )
            @label_win.clrtoeol

            # Draw the year in.
            temp = format('%d', @year)
            year_len = temp.size

            Slithernix::Cdk::Draw.writeChar(
              @label_win,
              @field_width - year_len,
              0,
              temp,
              Slithernix::Cdk::HORIZONTAL,
              0,
              year_len
            )

            @label_win.move(0, 0)
            @label_win.refresh
          elsif save_y >= 0
            @input_window.move(save_y, save_x)
            @input_window.refresh
          end
        end

        # This sets multiple attributes of the widget
        def set(day, month, _year, day_attrib, month_attrib, year_attrib, highlight, box)
          setDate(day, month, yar)
          setDayAttribute(day_attrib)
          setMonthAttribute(month_attrib)
          setYearAttribute(year_attrib)
          setHighlight(highlight)
          setBox(box)
        end

        # This sets the date and some attributes.
        def setDate(day, month, year)
          # Get the current dates and set the default values for the
          # day/month/year values for the calendar
          date_info = Time.new.gmtime

          # Set the date elements if we need to.
          @day = day == -1 ? date_info.day : day
          @month = month == -1 ? date_info.month : month
          @year = year == -1 ? date_info.year : year

          # Verify the date information.
          verifyCalendarDate

          # Get the start of the current month.
          @week_day = Slithernix::Cdk::Widget::Calendar.getMonthStartWeekday(
            @year,
            @month,
          )
        end

        # This returns the current date on the calendar.
        def getDate(day, month, year)
          day << @day
          month << @month
          year << @year
        end

        # This sets the attribute of the days in the calendar.
        def setDayAttribute(attribute)
          @day_attrib = attribute
        end

        def getDayAttribute
          @day_attrib
        end

        # This sets the attribute of the month names in the calendar.
        def setMonthAttribute(attribute)
          @month_attrib = attribute
        end

        def getMonthAttribute
          @month_attrib
        end

        # This sets the attribute of the year in the calendar.
        def setYearAttribute(attribute)
          @year_attrib = attribute
        end

        def getYearAttribute
          @year_attrib
        end

        # This sets the attribute of the highlight box.
        def setHighlight(highlight)
          @highlight = highlight
        end

        def getHighlight
          @highlight
        end

        # This sets the background attribute of the widget.
        def setBKattr(attrib)
          @win.wbkgd(attrib)
          @field_win.wbkgd(attrib)
          @label_win.wbkgd(attrib) unless @label_win.nil?
        end

        # This erases the calendar widget.
        def erase
          return unless validCDKObject

          Slithernix::Cdk.eraseCursesWindow(@label_win)
          Slithernix::Cdk.eraseCursesWindow(@field_win)
          Slithernix::Cdk.eraseCursesWindow(@win)
          Slithernix::Cdk.eraseCursesWindow(@shadow_win)
        end

        # This destroys the calendar
        def destroy
          cleanTitle

          Slithernix::Cdk.deleteCursesWindow(@label_win)
          Slithernix::Cdk.deleteCursesWindow(@field_win)
          Slithernix::Cdk.deleteCursesWindow(@shadow_win)
          Slithernix::Cdk.deleteCursesWindow(@win)

          # Clean the key bindings.
          cleanBindings(:Calendar)

          # Unregister the widget.
          Slithernix::Cdk::Screen.unregister(:Calendar, self)
        end

        # This sets a marker on the calendar.
        def setMarker(day, month, year, marker)
          year_index = Slithernix::Cdk::Widget::Calendar.YEAR2INDEX(year)
          oldmarker = getMarker(day, month, year)

          # Check to see if a marker has not already been set
          if oldmarker.zero?
            setCalendarCell(day, month, year_index, marker)
          else
            setCalendarCell(day, month, year_index,
                            oldmarker | Curses::A_BLINK)
          end
        end

        def getMarker(day, month, year)
          result = 0
          year = Slithernix::Cdk::Widget::Calendar.YEAR2INDEX(year)
          result = getCalendarCell(day, month, year) if @marker != 0
          result
        end

        # This sets a marker on the calendar.
        def removeMarker(day, month, year)
          year_index = Slithernix::Cdk::Widget::Calendar.YEAR2INDEX(year)
          setCalendarCell(day, month, year_index, 0)
        end

        # THis function sets the month name.
        def setMonthNames(months)
          (1...[months.size, @month_name.size].min).each do |x|
            @month_name[x] = months[x]
          end
        end

        # This function sets the day's name
        def setDaysNames(days)
          @day_name = days.clone
        end

        # This makes sure that the dates provided exist.
        def verifyCalendarDate
          # Make sure the given year is not less than 1900.
          @year = 1900 if @year < 1900

          # Make sure the month is within range.
          @month = 12 if @month > 12
          @month = 1 if @month < 1

          # Make sure the day given is within range of the month.
          month_length = Slithernix::Cdk::Widget::Calendar.getMonthLength(
            @year, @month
          )
          @day = 1 if @day < 1
          @day = month_length if @day > month_length
        end

        # This returns what day of the week the month starts on.
        def self.getMonthStartWeekday(year, month)
          Time.mktime(year, month, 1, 10, 0, 0).wday
        end

        # This function returns a 1 if it's a leap year and 0 if not.
        def self.isLeapYear(year)
          result = false
          if (year % 4).zero?
            if (year % 100).zero?
              result = true if (year % 400).zero?
            else
              result = true
            end
          end
          result
        end

        # This increments the current day by the given value.
        def incrementCalendarDay(adjust)
          month_length = Slithernix::Cdk::Widget::Calendar.getMonthLength(
            @year, @month
          )

          # Make sure we adjust the day correctly.
          if adjust + @day > month_length
            # Have to increment the month by one.
            @day = @day + adjust - month_length
            incrementCalendarMonth(1)
          else
            @day += adjust
            drawField
          end
        end

        # This decrements the current day by the given value.
        def decrementCalendarDay(adjust)
          # Make sure we adjust the day correctly.
          if @day - adjust < 1
            # Set the day according to the length of the month.
            if @month == 1
              # make sure we aren't going past the year limit.
              if @year == 1900
                mesg = [
                  '<C></U>Error',
                  'Can not go past the year 1900'
                ]
                Slithernix::Cdk.Beep
                @screen.popupLabel(mesg, 2)
                return
              end
              month_length = Slithernix::Cdk::Widget::Calendar.getMonthLength(
                @year - 1, 12
              )
            else
              month_length = Slithernix::Cdk::Widget::Calendar.getMonthLength(
                @year, @month - 1
              )
            end

            @day = month_length - (adjust - @day)

            # Have to decrement the month by one.
            decrementCalendarMonth(1)
          else
            @day -= adjust
            drawField
          end
        end

        # This increments the current month by the given value.
        def incrementCalendarMonth(adjust)
          # Are we at the end of the year.
          if @month + adjust > 12
            @month = @month + adjust - 12
            @year += 1
          else
            @month += adjust
          end

          # Get the length of the current month.
          month_length = Slithernix::Cdk::Widget::Calendar.getMonthLength(
            @year, @month
          )
          @day = month_length if @day > month_length

          # Get the start of the current month.
          @week_day = Slithernix::Cdk::Widget::Calendar.getMonthStartWeekday(
            @year, @month
          )

          # Redraw the calendar.
          erase
          draw(@box)
        end

        # This decrements the current month by the given value.
        def decrementCalendarMonth(adjust)
          # Are we at the end of the year.
          if @month <= adjust
            if @year == 1900
              mesg = [
                '<C></U>Error',
                'Can not go past the year 1900',
              ]
              Slithernix::Cdk.Beep
              @screen.popupLabel(mesg, 2)
              return
            else
              @month = 13 - adjust
              @year -= 1
            end
          else
            @month -= adjust
          end

          # Get the length of the current month.
          month_length = Slithernix::Cdk::Widget::Calendar.getMonthLength(
            @year, @month
          )
          @day = month_length if @day > month_length

          # Get the start o the current month.
          @week_day = Slithernix::Cdk::Widget::Calendar.getMonthStartWeekday(
            @year, @month
          )

          # Redraw the calendar.
          erase
          draw(@box)
        end

        # This increments the current year by the given value.
        def incrementCalendarYear(adjust)
          # Increment the year.
          @year += adjust

          # If we are in Feb make sure we don't trip into voidness.
          if @month == 2
            month_length = Slithernix::Cdk::Widget::Calendar.getMonthLength(
              @year, @month
            )
            @day = month_length if @day > month_length
          end

          # Get the start of the current month.
          @week_day = Slithernix::Cdk::Widget::Calendar.getMonthStartWeekday(
            @year, @month
          )

          # Redraw the calendar.
          erase
          draw(@box)
        end

        # This decrements the current year by the given value.
        def decrementCalendarYear(adjust)
          # Make sure we don't go out o bounds.
          if @year - adjust < 1900
            mesg = [
              '<C></U>Error',
              'Can not go past the year 1900',
            ]
            Slithernix::Cdk.Beep
            @screen.popupLabel(mesg, 2)
            return
          end

          # Decrement the year.
          @year -= adjust

          # If we are in Feb make sure we don't trip into voidness.
          if @month == 2
            month_length = Slithernix::Cdk::Widget::Calendar.getMonthLength(
              @year, @month
            )
            @day = month_length if @day > month_length
          end

          # Get the start of the current month.
          @week_day = Slithernix::Cdk::Widget::Calendar.getMonthStartWeekday(
            @year, @month
          )

          # Redraw the calendar.
          erase
          draw(@box)
        end

        # This returns the length of the current month.
        def self.getMonthLength(year, month)
          month_length = DAYS_OF_THE_MONTH[month]

          if month == 2
            month_length += if Slithernix::Cdk::Widget::Calendar.isLeapYear(year)
                            then 1
                            else
                              0
                            end
          end

          month_length
        end

        # This returns what day of the week the month starts on.
        def getCurrentTime
          # Determine the current time and determine if we are in DST.
          Time.mktime(@year, @month, @day, 0, 0, 0).gmtime
        end

        def focus
          # Original: drawCDKFscale(widget, ObjOf (widget)->box);
          draw(@box)
        end

        def unfocus
          # Original: drawCDKFscale(widget, ObjOf (widget)->box);
          draw(@box)
        end

        def self.YEAR2INDEX(year)
          if year >= 1900
            year - 1900
          else
            year
          end
        end

        def position
          super(@win)
        end
      end
    end
  end
end
