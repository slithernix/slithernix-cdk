require_relative '../objects'

module Cdk
  class SLIDER < Cdk::Objects
    def initialize(cdkscreen, xplace, yplace, title, label, filler,
        field_width, start, low, high, inc, fast_inc, box, shadow)
      super()
      parent_width = cdkscreen.window.maxx
      parent_height = cdkscreen.window.maxy
      bindings = {
        'u'           => Curses::KEY_UP,
        'U'           => Curses::KEY_PPAGE,
        Cdk::BACKCHAR => Curses::KEY_PPAGE,
        Cdk::FORCHAR  => Curses::KEY_NPAGE,
        'g'           => Curses::KEY_HOME,
        '^'           => Curses::KEY_HOME,
        'G'           => Curses::KEY_END,
        '$'           => Curses::KEY_END,
      }
      self.setBox(box)
      box_height = @border_size * 2 + 1

      # Set some basic values of the widget's data field.
      @label = []
      @label_len = 0
      @label_win = nil
      high_value_len = self.formattedSize(high)

      # If the field_width is a negative will be COLS-field_width,
      # otherwise field_width will be the given width.
      field_width = Cdk.setWidgetDimension(parent_width, field_width, 0)

      # Translate the label string to a chtype array.
      if !(label.nil?) && label.size > 0
        label_len = []
        @label = Cdk.char2Chtype(label, label_len, [])
        @label_len = label_len[0]
        box_width = @label_len + field_width +
            high_value_len + 2 * @border_size
      else
        box_width = field_width + high_value_len + 2 * @border_size
      end

      old_width = box_width
      box_width = self.setTitle(title, box_width)
      horizontal_adjust = (box_width - old_width) / 2

      box_height += @title_lines

      # Make sure we didn't extend beyond the dimensions of the window.
      box_width = [box_width, parent_width].min
      box_height = [box_height, parent_height].min
      field_width = [field_width,
          box_width - @label_len - high_value_len - 1].min

      # Rejustify the x and y positions if we need to.
      xtmp = [xplace]
      ytmp = [yplace]
      Cdk.alignxy(cdkscreen.window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Make the widget's window.
      @win = Curses::Window.new(box_height, box_width, ypos, xpos)

      # Is the main window nil?
      if @win.nil?
        self.destroy
        return nil
      end

      # Create the widget's label window.
      if @label.size > 0
        @label_win = @win.subwin(1, @label_len,
            ypos + @title_lines + @border_size,
            xpos + horizontal_adjust + @border_size)
        if @label_win.nil?
          self.destroy
          return nil
        end
      end

      # Create the widget's data field window.
      @field_win = @win.subwin(1, field_width + high_value_len - 1,
          ypos + @title_lines + @border_size,
          xpos + @label_len + horizontal_adjust + @border_size)

      if @field_win.nil?
        self.destroy
        return nil
      end
      @field_win.keypad(true)
      @win.keypad(true)

      # Create the widget's data field.
      @screen = cdkscreen
      @window = cdkscreen.window
      @shadow_win = nil
      @box_width = box_width
      @box_height = box_height
      @field_width = field_width - 1
      @filler = filler
      @low = low
      @high = high
      @current = start
      @inc = inc
      @fastinc = fast_inc
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow
      @field_edit = 0

      # Set the start value.
      if start < low
        @current = low
      end

      # Do we want a shadow?
      if shadow
        @shadow_win = Curses::Window.new(box_height, box_width,
            ypos + 1, xpos + 1)
        if @shadow_win.nil?
          self.destroy
          return nil
        end
      end

      # Setup the key bindings.
      bindings.each do |from, to|
        self.bind(:SLIDER, from, :getc, to)
      end

      cdkscreen.register(:SLIDER, self)
    end

    # This allows the person to use the widget's data field.
    def activate(actions)
      # Draw the widget.
      self.draw(@box)

      if actions.nil? || actions.size == 0
        while true
          input = self.getch([])

          # Inject the character into the widget.
          ret = self.inject(input)
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      else
        # Inject each character one at a time.
        actions.each do |action|
          ret = self.inject(action)
          if @exit_type != :EARLY_EXIT
            return ret
          end
        end
      end

      # Set the exit type and return.
      self.setExitType(0)
      return -1
    end

    # Check if the value lies outside the low/high range. If so, force it in.
    def limitCurrentValue
      if @current < @low
        @current = @low
        Cdk.Beep
      elsif @current > @high
        @current = @high
        Cdk.Beep
      end
    end

    # Move the cursor to the given edit-position.
    def moveToEditPosition(new_position)
      #return @field_win.move(0,
      #    @field_width + self.formattedSize(@current) - new_position)
      @field_win
    end

    # Check if the cursor is on a valid edit-position. This must be one of
    # the non-blank cells in the field.
    def validEditPosition(new_position)
      if new_position <= 0 || new_position >= @field_width
        return false
      end
      if self.moveToEditPosition(new_position) == Curses::Error
        return false
      end
      ch = @field_win.inch
      if Cdk.CharOf(ch) != ' '
        return true
      end
      if new_position > 1
        # Don't use recursion - only one level is wanted
        if self.moveToEditPosition(new_position - 1) == Curses::Error
          return false
        end
        ch = @field_win.inch
        return Cdk.CharOf(ch) != ' '
      end
      return false
    end

    # Set the edit position.  Normally the cursor is one cell to the right of
    # the editable field.  Moving it left, over the field, allows the user to
    # modify cells by typing in replacement characters for the field's value.
    def setEditPosition(new_position)
      if new_position < 0
        Cdk.Beep
      elsif new_position == 0
        @field_edit = new_position
      elsif self.validEditPosition(new_position)
        @field_edit = new_position
      else
        Cdk.Beep
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
      return result
    end

    # Perform an editing function for the field.
    def performEdit(input)
      result = false
      modify = true
      base = @field_width
      need = self.formattedSize(@current)
      temp = ''
      col = need - @field_edit

      adj = if col < 0 then -col else 0 end
      if adj != 0
        temp  = ' ' * adj
      end
      @field_win.move(0, base)
      @field_win.winnstr(temp, need)
      temp << ' '
      if Cdk.isChar(input)  # Replace the char at the cursor
        temp[col] = input.chr
      elsif input == Curses::KEY_BACKSPACE
        # delete the char before the cursor
        modify = Cdk::SLIDER.removeChar(temp, col - 1)
      elsif input == Curses::KEY_DC
        # delete the char at the cursor
        modify = Cdk::SLIDER.removeChar(temp, col)
      else
        modify = false
      end
      if modify &&
          ((value, test) = temp.scanf(self.SCAN_FMT)).size == 2 &&
          test == ' ' && value >= @low && value <= @high
        self.setValue(value)
        result = true
      end
      return result
    end

    def self.Decrement(value, by)
      if value - by < value
        value - by
      else
        value
      end
    end

    def self.Increment(value, by)
      if value + by > value
        value + by
      else
        value
      end
    end

    # This function injects a single character into the widget.
    def inject(input)
      pp_return = 1
      ret = -1
      complete = false

      # Set the exit type.
      self.setExitType(0)

      # Draw the field.
      self.drawField

      # Check if there is a pre-process function to be called.
      unless @pre_process_func.nil?
        # Call the pre-process function.
        pp_return = @pre_process_func.call(:SLIDER, self,
            @pre_process_data, input)
      end

      # Should we continue?
      if pp_return != 0
        # Check for a key binding.
        if self.checkBind(:SLIDER, input)
          complete = true
        else
          case input
          when Curses::KEY_LEFT
            self.setEditPosition(@field_edit + 1)
          when Curses::KEY_RIGHT
            self.setEditPosition(@field_edit - 1)
          when Curses::KEY_DOWN
            @current = Cdk::SLIDER.Decrement(@current, @inc)
          when Curses::KEY_UP
            @current = Cdk::SLIDER.Increment(@current, @inc)
          when Curses::KEY_PPAGE
            @current = Cdk::SLIDER.Increment(@current, @fastinc)
          when Curses::KEY_NPAGE
            @current = Cdk::SLIDER.Decrement(@current, @fastinc)
          when Curses::KEY_HOME
            @current = @low
          when Curses::KEY_END
            @current = @high
          when Cdk::KEY_TAB, Cdk::KEY_RETURN, Curses::KEY_ENTER
            self.setExitType(input)
            ret = @current
            complete = true
          when Cdk::KEY_ESC
            self.setExitType(input)
            complete = true
          when Curses::Error
            self.setExitType(input)
            complete = true
          when Cdk::REFRESH
            @screen.erase
            @screen.refresh
          else
            if @field_edit != 0
              if !self.performEdit(input)
                Cdk.Beep
              end
            else
              # The cursor is not within the editable text. Interpret
              # input as commands.
            case input
            when 'd', '-'
              return self.inject(Curses::KEY_DOWN)
            when '+'
              return self.inject(Curses::KEY_UP)
            when 'D'
              return self.inject(Curses::KEY_NPAGE)
            when '0'
              return self.inject(Curses::KEY_HOME)
            else
              Cdk.Beep
            end
            end
          end
        end
        self.limitCurrentValue

        # Should we call a post-process?
        if !complete && !(@post_process_func.nil?)
          @post_process_func.call(:SLIDER, self, @post_process_data, input)
        end
      end

      if !complete
        self.drawField
        self.setExitType(0)
      end

      @return_data = 0
      return ret
    end

    # This moves the widget's data field to the given location.
    def move(xplace, yplace, relative, refresh_flag)
      windows = [@win, @label_win, @field_win, @shadow_win]
      self.move_specific(xplace, yplace, relative, refresh_flag,
          windows, [])
    end

    # This function draws the widget.
    def draw(box)
      # Draw the shadow.
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box the widget if asked.
      if box
        Draw.drawObjBox(@win, self)
      end

      self.drawTitle(@win)

      # Draw the label.
      unless @label_win.nil?
        Draw.writeChtype(@label_win, 0, 0, @label, Cdk::HORIZONTAL,
                         0, @label_len)
        @label_win.refresh
      end
      @win.refresh

      # Draw the field window.
      self.drawField
    end

    # This draws the widget.
    def drawField
      step = 1.0 * @field_width / (@high - @low)

      # Determine how many filler characters need to be drawn.
      filler_characters = (@current - @low) * step

      @field_win.erase

      # Add the character to the window.
      (0...filler_characters).each do |x|
        @field_win.mvwaddch(0, x, @filler)
      end

      # Draw the value in the field.
      Draw.writeCharAttrib(@field_win, @field_width, 0, @current.to_s,
                           Curses::A_NORMAL, Cdk::HORIZONTAL, 0, @current.to_s.size)

      self.moveToEditPosition(@field_edit)
      @field_win.refresh
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      # Set the widget's background attribute.
      @win.wbkgd(attrib)
      @field_win.wbkgd(attrib)
      unless @label_win.nil?
        @label_win.wbkgd(attrib)
      end
    end

    # This function destroys the widget.
    def destroy
      self.cleanTitle
      @label = []

      # Clean up the windows.
      Cdk.deleteCursesWindow(@field_win)
      Cdk.deleteCursesWindow(@label_win)
      Cdk.deleteCursesWindow(@shadow_win)
      Cdk.deleteCursesWindow(@win)

      # Clean the key bindings.
      self.cleanBindings(:SLIDER)

      # Unregister this object.
      Cdk::Screen.unregister(:SLIDER, self)
    end

    # This function erases the widget from the screen.
    def erase
      if self.validCDKObject
        Cdk.eraseCursesWindow(@label_win)
        Cdk.eraseCursesWindow(@field_win)
        Cdk.eraseCursesWindow(@lwin)
        Cdk.eraseCursesWindow(@shadow_win)
      end
    end

    def formattedSize(value)
      return value.to_s.size
    end

    # This function sets the low/high/current values of the widget.
    def set(low, high, value, box)
      self.setLowHigh(low, high)
      self.setValue(value)
      self.setBox(box)
    end

    # This sets the widget's value.
    def setValue(value)
      @current = value
      self.limitCurrentValue
    end

    def getValue
      return @current
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
      self.limitCurrentValue
    end

    def getLowValue
      return @low
    end

    def getHighValue
      return @high
    end

    def focus
      self.draw(@box)
    end

    def unfocus
      self.draw(@box)
    end

    def SCAN_FMT
      '%d%c'
    end

    def position
      super(@win)
    end

    def object_type
      :SLIDER
    end
  end
end
