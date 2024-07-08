# frozen_string_literal: true

require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class Scale < Slithernix::Cdk::Widget
        def initialize(cdkscreen, xplace, yplace, title, label, field_attr,
                       field_width, start, low, high, inc, fast_inc, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          bindings = {
            'u' => Curses::KEY_UP,
            'U' => Curses::KEY_PPAGE,
            Slithernix::Cdk::BACKCHAR => Curses::KEY_PPAGE,
            Slithernix::Cdk::FORCHAR => Curses::KEY_NPAGE,
            'g' => Curses::KEY_HOME,
            '^' => Curses::KEY_HOME,
            'G' => Curses::KEY_END,
            '$' => Curses::KEY_END
          }

          set_box(box)

          box_height = (@border_size * 2) + 1
          (2 * @border_size)

          # Set some basic values of the widget's data field.
          @label = []
          @label_len = 0
          @label_win = nil

          # If the field_width is a negative value, the field_width will
          # be COLS-field_width, otherwise the field_width will be the
          # given width.
          field_width = Slithernix::Cdk.setWidgetDimension(parent_width,
                                                           field_width, 0)
          box_width = field_width + (2 * @border_size)

          # Translate the label string to a chtype array
          unless label.nil?
            label_len = []
            @label = Slithernix::Cdk.char2Chtype(label, label_len, [])
            @label_len = label_len[0]
            box_width = @label_len + field_width + 2
          end

          old_width = box_width
          box_width = set_title(title, box_width)
          horizontal_adjust = (box_width - old_width) / 2

          box_height += @title_lines

          # Make sure we didn't extend beyond the dimensions of the window.
          box_width = [box_width, parent_width].min
          box_height = [box_height, parent_height].min
          field_width = [field_width,
                         box_width - @label_len - (2 * @border_size)].min

          # Rejustify the x and y positions if we need to.
          xtmp = [xplace]
          ytmp = [yplace]
          Slithernix::Cdk.alignxy(cdkscreen.window, xtmp, ytmp, box_width,
                                  box_height)
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Make the widget's window.
          @win = Curses::Window.new(box_height, box_width, ypos, xpos)

          # Is the main window nil?
          if @win.nil?
            destroy
            return nil
          end

          # Create the widget's label window.
          if @label.size.positive?
            @label_win = @win.subwin(1, @label_len,
                                     ypos + @title_lines + @border_size,
                                     xpos + horizontal_adjust + @border_size)
            if @label_win.nil?
              destroy
              return nil
            end
          end

          # Create the widget's data field window.
          @field_win = @win.subwin(1, field_width,
                                   ypos + @title_lines + @border_size,
                                   xpos + @label_len + horizontal_adjust + @border_size)

          if @field_win.nil?
            destroy
            return nil
          end
          @field_win.keypad(true)
          @win.keypad(true)

          # Create the widget's data field.
          @screen = cdkscreen
          @parent = cdkscreen.window
          @shadow_win = nil
          @box_width = box_width
          @box_height = box_height
          @field_width = field_width
          @field_attr = field_attr
          @current = low
          @low = low
          @high = high
          @current = start
          @inc = inc
          @fastinc = fast_inc
          @accepts_focus = true
          @input_window = @win
          @shadow = shadow
          @field_edit = 0

          # Do we want a shadow?
          if shadow
            @shadow_win = Curses::Window.new(box_height, box_width,
                                             ypos + 1, xpos + 1)
            if @shadow_win.nil?
              destroy
              return nil
            end
          end

          # Setup the key bindings.
          bindings.each do |from, to|
            bind(widget_type, from, :getc, to)
          end

          cdkscreen.register(widget_type, self)
        end

        # This allows the person to use the widget's data field.
        def activate(actions)
          ret = -1
          # Draw the widget.
          draw(@box)

          if actions.nil? || actions.empty?
            input = 0
            loop do
              input = getch([])

              # Inject the character into the widget.
              ret = inject(input)
              return ret if @exit_type != :EARLY_EXIT
            end
          else
            # Inject each character one at a time.
            actions.each do |action|
              ret = inject(action)
            end
            return ret if @exit_type != :EARLY_EXIT
          end

          # Set the exit type and return.
          set_exit_type(0)
          ret
        end

        # Check if the value lies outsid the low/high range. If so, force it in.
        def limitCurrentValue
          if @current < @low
            @current = @low
            Slithernix::Cdk.Beep
          elsif @current > @high
            @current = @high
            Slithernix::Cdk.Beep
          end
        end

        # Move the cursor to the given edit-position
        # Once again, I cannot figure out why this move method is called
        # and removing the call fixes the widget.
        def moveToEditPosition(_new_position)
          # return @field_win.move(0, @field_width - new_position - 1)
          # return @field_win.move(24, @field_width - new_position - 1)
          @field_win
        end

        # Check if the cursor is on a valid edit-position. This must be one of
        # the non-blank cells in the field.
        def validEditPosition(new_position)
          return false if new_position <= 0 || new_position >= @field_width
          return false if moveToEditPosition(new_position) == Curses::Error

          ch = @field_win.inch
          return true if ch.chr != ' '

          if new_position > 1
            # Don't use recursion - only one level is wanted
            if moveToEditPosition(new_position - 1) == Curses::Error
              return false
            end

            ch = @field_win.inch
            return ch.chr != ' '
          end
          false
        end

        # Set the edit position. Normally the cursor is one cell to the right of
        # the editable field.  Moving it left over the field allows the user to
        # modify cells by typing in replacement characters for the field's value.
        def setEditPosition(new_position)
          if new_position.negative?
            Slithernix::Cdk.Beep
          elsif new_position.zero?
            @field_edit = new_position
          elsif validEditPosition(new_position)
            @field_edit = new_position
          else
            Slithernix::Cdk.Beep
          end
        end

        # Remove the character from the string at the given column, if it is blank.
        # Returns true if a change was made.
        def self.removeChar(string, col)
          result = false
          if col >= 0 && string[col] != ' '
            while col < string.size - 1
              string[col] = string[col + 1]
              col += 1
            end
            string.chop!
            result = true
          end
          result
        end

        # Perform an editing function for the field.
        def performEdit(input)
          result = false
          modify = true
          base = 0
          need = @field_width
          temp = String.new
          col = need - @field_edit - 1

          @field_win.move(0, base)
          @field_win.winnstr(temp, need)
          temp << ' '
          if Slithernix::Cdk.isChar(input) # Replace the char at the cursor
            temp[col] = input.chr
          elsif input == Curses::KEY_BACKSPACE
            # delete the char before the cursor
            modify = Slithernix::Cdk::Widget::Scale.removeChar(temp, col - 1)
          elsif input == Curses::KEY_DC
            # delete the char at the cursor
            modify = Slithernix::Cdk::Widget::Scale.removeChar(temp, col)
          else
            modify = false
          end
          if modify &&
             ((value, test) = temp.scanf(self.SCAN_FMT)).size == 2 &&
             test == ' ' &&
             value >= @low && value <= @high
            setValue(value)
            result = true
          end

          result
        end

        def self.Decrement(value, by)
          [value - by, value].min
        end

        def self.Increment(value, by)
          [value + by, value].max
        end

        # This function injects a single character into the widget.
        def inject(input)
          pp_return = 1
          ret = -1
          complete = false

          # Set the exit type.
          set_exit_type(0)

          # Draw the field.
          drawField

          # Check if there is a pre-process function to be called.
          unless @pre_process_func.nil?
            # Call the pre-process function.
            pp_return = @pre_process_func.call(widget_type, self,
                                               @pre_process_data, input)
          end

          # Should we continue?
          if pp_return != 0
            # Check for a key bindings.
            if check_bind(widget_type, input)
              complete = true
            else
              case input
              when Curses::KEY_LEFT
                setEditPosition(@field_edit + 1)
              when Curses::KEY_RIGHT
                setEditPosition(@field_edit - 1)
              when Curses::KEY_DOWN
                @current = Slithernix::Cdk::Widget::Scale.Decrement(@current,
                                                                    @inc)
              when Curses::KEY_UP
                @current = Slithernix::Cdk::Widget::Scale.Increment(@current,
                                                                    @inc)
              when Curses::KEY_PPAGE
                @current = Slithernix::Cdk::Widget::Scale.Increment(@current,
                                                                    @fastinc)
              when Curses::KEY_NPAGE
                @current = Slithernix::Cdk::Widget::Scale.Decrement(@current,
                                                                    @fastinc)
              when Curses::KEY_HOME
                @current = @low
              when Curses::KEY_END
                @current = @high
              when Slithernix::Cdk::KEY_TAB, Slithernix::Cdk::KEY_RETURN, Curses::KEY_ENTER
                set_exit_type(input)
                ret = @current
                complete = true
              when Slithernix::Cdk::KEY_ESC
                set_exit_type(input)
                complete = true
              when Curses::Error
                set_exit_type(input)
                complete = true
              when Slithernix::Cdk::REFRESH
                @screen.erase
                @screen.refresh
              else
                if @field_edit.zero?
                  # The cursor is not within the editable text. Interpret
                  # input as commands.
                  case input
                  when 'd', '-'
                    return inject(Curses::KEY_DOWN)
                  when '+'
                    return inject(Curses::KEY_UP)
                  when 'D'
                    return inject(Curses::KEY_NPAGE)
                  when '0'
                    return inject(Curses::KEY_HOME)
                  else
                    Slithernix::Cdk.Beep
                  end
                else
                  Slithernix::Cdk.Beep unless performEdit(input)
                end
              end
            end
            limitCurrentValue

            # Should we call a post-process?
            if !complete && @post_process_func
              @post_process_func.call(widget_type, self,
                                      @post_process_data, input)
            end
          end

          unless complete
            drawField
            set_exit_type(0)
          end

          @result_data = ret
          ret
        end

        # This moves the widget's data field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@win, @label_win, @field_win, @shadow_win]
          move_specific(xplace, yplace, relative, refresh_flag,
                        windows, [])
        end

        # This function draws the widget.
        def draw(box)
          # Draw the shadow.
          Slithernix::Cdk::Draw.draw_shadow(@shadow_win) unless @shadow_win.nil?

          # Box the widget if asked.
          Slithernix::Cdk::Draw.draw_obj_box(@win, self) if box

          draw_title(@win)

          # Draw the label.
          unless @label_win.nil?
            Slithernix::Cdk::Draw.write_chtype(@label_win, 0, 0, @label, Slithernix::Cdk::HORIZONTAL,
                                               0, @label_len)
            @label_win.refresh
          end
          @win.refresh

          # Draw the field window.
          drawField
        end

        # This draws the widget.
        def drawField
          @field_win.erase

          # Draw the value in the field.
          temp = @current.to_s
          Slithernix::Cdk::Draw.write_char_attrib(@field_win,
                                                  @field_width - temp.size - 1, 0, temp, @field_attr,
                                                  Slithernix::Cdk::HORIZONTAL, 0, temp.size)

          moveToEditPosition(@field_edit)
          @field_win.refresh
        end

        # This sets the background attribute of teh widget.
        def setBKattr(attrib)
          @win.wbkgd(attrib)
          @field_win.wbkgd(attrib)
          @label_win&.wbkgd(attrib)
        end

        # This function destroys the widget.
        def destroy
          clean_title
          @label = []

          # Clean up the windows.
          Slithernix::Cdk.deleteCursesWindow(@field_win)
          Slithernix::Cdk.deleteCursesWindow(@label_win)
          Slithernix::Cdk.deleteCursesWindow(@shadow_win)
          Slithernix::Cdk.deleteCursesWindow(@win)

          # Clean the key bindings.
          clean_bindings(widget_type)

          # Unregister this widget
          Slithernix::Cdk::Screen.unregister(widget_type, self)
        end

        # This function erases the widget from the screen.
        def erase
          return unless is_valid_widget?

          Slithernix::Cdk.eraseCursesWindow(@label_win)
          Slithernix::Cdk.eraseCursesWindow(@field_win)
          Slithernix::Cdk.eraseCursesWindow(@win)
          Slithernix::Cdk.eraseCursesWindow(@shadow_win)
        end

        # This function sets the low/high/current values of the widget.
        def set(low, high, value, box)
          setLowHigh(low, high)
          setValue(value)
          set_box(box)
        end

        # This sets the widget's value
        def setValue(value)
          @current = value
          limitCurrentValue
        end

        def getValue
          @current
        end

        # This function sets the low/high values of the widget.
        def setLowHigh(low, high)
          # Make sure the values aren't out of bounds.
          if low <= high
            @low = low
            @high = high
          elsif low > high
            @low = high
            @high = low
          end

          # Make sure the user hasn't done something silly.
          limitCurrentValue
        end

        def getLowValue
          @low
        end

        def getHighValue
          @high
        end

        def focus
          draw(@box)
        end

        def unfocus
          draw(@box)
        end

        def position
          super(@win)
        end

        def SCAN_FMT
          '%d%c'
        end
      end
    end
  end
end
