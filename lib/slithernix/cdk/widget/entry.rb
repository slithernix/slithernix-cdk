require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class Entry < Slithernix::Cdk::Widget
        attr_accessor :info, :left_char, :screen_col
        attr_reader :win, :box_height, :box_width, :max, :field_width, :min

        def initialize(cdkscreen, xplace, yplace, title, label, field_attr, filler,
                       disp_type, f_width, min, max, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          field_width = f_width
          box_width = 0
          xpos = xplace
          ypos = yplace

          setBox(box)
          box_height = (@border_size * 2) + 1

          # If the field_width is a negative value, the field_width will be
          # COLS-field_width, otherwise the field_width will be the given width.
          field_width = Slithernix::Cdk.setWidgetDimension(parent_width,
                                                           field_width, 0)
          box_width = field_width + (2 * @border_size)

          # Set some basic values of the entry field.
          @label = 0
          @label_len = 0
          @label_win = nil

          # Translate the label string to a chtype array
          if !label.nil? && label.size > 0
            label_len = [@label_len]
            @label = Slithernix::Cdk.char2Chtype(label, label_len, [])
            @label_len = label_len[0]
            box_width += @label_len
          end

          old_width = box_width
          box_width = setTitle(title, box_width)
          horizontal_adjust = (box_width - old_width) / 2

          box_height += @title_lines

          # Make sure we didn't extend beyond the dimensinos of the window.
          box_width = [box_width, parent_width].min
          box_height = [box_height, parent_height].min
          field_width = [field_width,
                         box_width - @label_len - (2 * @border_size)].min

          # Rejustify the x and y positions if we need to.
          xtmp = [xpos]
          ytmp = [ypos]
          Slithernix::Cdk.alignxy(cdkscreen.window, xtmp, ytmp, box_width,
                                  box_height)
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Make the label window.
          @win = cdkscreen.window.subwin(box_height, box_width, ypos, xpos)
          if @win.nil?
            destroy
            return nil
          end
          @win.keypad(true)

          # Make the field window.
          @field_win = @win.subwin(1, field_width,
                                   ypos + @title_lines + @border_size,
                                   xpos + @label_len + horizontal_adjust + @border_size)

          if @field_win.nil?
            destroy
            return nil
          end
          @field_win.keypad(true)

          # make the label win, if we need to
          if !label.nil? && label.size > 0
            @label_win = @win.subwin(1, @label_len,
                                     ypos + @title_lines + @border_size,
                                     xpos + horizontal_adjust + @border_size)
          end

          # cleanChar (entry->info, max + 3, '\0');
          @info = ''
          @info_width = max + 3

          # Set up the rest of the structure.
          @screen = cdkscreen
          @parent = cdkscreen.window
          @shadow_win = nil
          @field_attr = field_attr
          @field_width = field_width
          @filler = filler
          @hidden = filler
          @input_window = @field_win
          @accepts_focus = true
          @data_ptr = nil
          @shadow = shadow
          @screen_col = 0
          @left_char = 0
          @min = min
          @max = max
          @box_width = box_width
          @box_height = box_height
          @disp_type = disp_type
          @callbackfn = lambda do |entry, character|
            plainchar = Slithernix::Cdk::Display.filterByDisplayType(entry,
                                                                     character)

            if plainchar == Curses::Error || entry.info.size >= entry.max
              Slithernix::Cdk.Beep
            else
              # Update the screen and pointer
              if entry.screen_col == entry.field_width - 1
                # Update the character pointer.
                entry.info << plainchar
                # Do not update the pointer if it's the last character
                entry.left_char += 1 if entry.info.size < entry.max
              else
                front = (entry.info[0...(entry.screen_col + entry.left_char)] or '')
                back = (entry.info[(entry.screen_col + entry.left_char)..-1] or '')
                entry.info = front + plainchar.chr + back
                entry.screen_col += 1
              end

              # Update the entry field.
              entry.drawField
            end
          end

          # Do we want a shadow?
          if shadow
            @shadow_win = cdkscreen.window.subwin(box_height, box_width,
                                                  ypos + 1, xpos + 1)
          end

          cdkscreen.register(:Entry, self)
        end

        # This means you want to use the given entry field. It takes input
        # from the keyboard, and when it's done, it fills the entry info
        # element of the structure with what was typed.
        def activate(actions)
          input = 0
          ret = 0

          # Draw the widget.
          draw(@box)

          if actions.nil? or actions.size == 0
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

          # Make sure we return the correct info.
          if @exit_type == :NORMAL
            @info
          else
            0
          end
        end

        def setPositionToEnd
          if @info.size >= @field_width
            if @info.size < @max
              char_count = @field_width - 1
              @left_char = @info.size - char_count
              @screen_col = char_count
            else
              @left_char = @info.size - @field_width
              @screen_col = @info.size - 1
            end
          else
            @left_char = 0
            @screen_col = @info.size
          end
        end

        # This injects a single character into the widget.
        def inject(input)
          pp_return = 1
          ret = 1
          complete = false

          # Set the exit type
          setExitType(0)

          # Refresh the widget field. This seems useless?
          # self.drawField

          unless @pre_process_func.nil?
            pp_return = @pre_process_func.call(
              :Entry,
              self,
              @pre_process_data,
              input,
            )
          end

          # Should we continue?
          if pp_return != 0
            # Check a predefined binding
            if checkBind(:Entry, input)
              complete = true
            else
              curr_pos = @screen_col + @left_char

              case input
              when Curses::KEY_UP, Curses::KEY_DOWN
                Slithernix::Cdk.Beep
              when Curses::KEY_HOME
                @left_char = 0
                @screen_col = 0
                drawField
              when Slithernix::Cdk::TRANSPOSE
                if curr_pos >= @info.size - 1
                  Slithernix::Cdk.Beep
                else
                  holder = @info[curr_pos]
                  @info[curr_pos] = @info[curr_pos + 1]
                  @info[curr_pos + 1] = holder
                  drawField
                end
              when Curses::KEY_END
                setPositionToEnd
                drawField
              when Curses::KEY_LEFT
                if curr_pos <= 0
                  Slithernix::Cdk.Beep
                elsif @screen_col == 0
                  # Scroll left.
                  @left_char -= 1
                  drawField
                else
                  @screen_col -= 1
                  # @field_win.move(0, @screen_col)
                end
              when Curses::KEY_RIGHT
                if curr_pos >= @info.size
                  Slithernix::Cdk.Beep
                elsif @screen_col == @field_width - 1
                  # Scroll to the right.
                  @left_char += 1
                  drawField
                else
                  # Move right.
                  @screen_col += 1
                  # @field_win.move(0, @screen_col)
                end
              when Curses::KEY_BACKSPACE, Curses::KEY_DC
                if @disp_type == :VIEWONLY
                  Slithernix::Cdk.Beep
                else
                  success = false
                  curr_pos -= 1 if input == Curses::KEY_BACKSPACE

                  if curr_pos >= 0 && @info.size > 0
                    if curr_pos < @info.size
                      @info = @info[0...curr_pos] + @info[curr_pos + 1..-1]
                      success = true
                    elsif input == Curses::KEY_BACKSPACE
                      @info = @info[0...-1]
                      success = true
                    end
                  end

                  if success
                    if input == Curses::KEY_BACKSPACE
                      if @screen_col > 0
                        @screen_col -= 1
                      else
                        @left_char -= 1
                      end
                    end
                    drawField
                  else
                    Slithernix::Cdk.Beep
                  end
                end
              when Slithernix::Cdk::KEY_ESC
                setExitType(input)
                complete = true
              when Slithernix::Cdk::ERASE
                if @info.size != 0
                  clean
                  drawField
                end
              when Slithernix::Cdk::CUT
                if @info.size == 0
                  Slithernix::Cdk.Beep
                else
                  @@g_paste_buffer = @info.clone
                  clean
                  drawField
                end
              when Slithernix::Cdk::COPY
                if @info.size == 0
                  Slithernix::Cdk.Beep
                else
                  @@g_paste_buffer = @info.clone
                end
              when Slithernix::Cdk::PASTE
                if @@g_paste_buffer == 0
                  Slithernix::Cdk.Beep
                else
                  setValue(@@g_paste_buffer)
                  drawField
                end
              when Slithernix::Cdk::KEY_TAB, Slithernix::Cdk::KEY_RETURN, Curses::KEY_ENTER
                if @info.size >= @min
                  setExitType(input)
                  ret = @info
                  complete = true
                else
                  Slithernix::Cdk.Beep
                end
              when Curses::Error
                setExitType(input)
                complete = true
              when Slithernix::Cdk::REFRESH
                @screen.erase
                @screen.refresh
              else
                @callbackfn.call(self, input)
              end
            end

            if !complete && !@post_process_func.nil?
              @post_process_func.call(:Entry, self, @post_process_data, input)
            end
          end

          setExitType(0) unless complete

          @result_data = ret
          ret
        end

        # This moves the entry field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@win, @field_win, @label_win, @shadow_win]
          move_specific(xplace, yplace, relative, refresh_flag,
                        windows, [])
        end

        # This erases the information in the entry field and redraws
        # a clean and empty entry field.
        def clean
          width = @field_width

          @info = ''

          # Clean the entry screen field.
          @field_win.mvwhline(0, 0, @filler.ord, width)

          # Reset some variables
          @screen_col = 0
          @left_char = 0

          # Refresh the entry field.
          @field_win.refresh
        end

        # This draws the entry field.
        def draw(box)
          # Did we ask for a shadow?
          Slithernix::Cdk::Draw.drawShadow(@shadow_win) unless @shadow_win.nil?

          # Box the widget if asked.
          Slithernix::Cdk::Draw.drawObjBox(@win, self) if box

          drawTitle(@win)

          @win.refresh

          # Draw in the label to the widget.
          unless @label_win.nil?
            Slithernix::Cdk::Draw.writeChtype(@label_win, 0, 0, @label, Slithernix::Cdk::HORIZONTAL, 0,
                                              @label_len)
            @label_win.refresh
          end

          drawField
        end

        def drawField
          # Draw in the filler characters.
          @field_win.mvwhline(0, 0, @filler.ord, @field_width)

          # If there is information in the field then draw it in.
          if !@info.nil? && @info.size > 0
            # Redraw the field.
            if Slithernix::Cdk::Display.isHiddenDisplayType(@disp_type)
              (@left_char...@info.size).each do |x|
                @field_win.mvwaddch(0, x - @left_char, @hidden)
              end
            else
              (@left_char...@info.size).each do |x|
                @field_win.mvwaddch(0, x - @left_char,
                                    @info[x].ord | @field_attr)
              end
            end
            # @field_win.move(0, @screen_col)
          end

          @field_win.refresh
        end

        # This erases an entry widget from the screen.
        def erase
          return unless validCDKObject

          Slithernix::Cdk.eraseCursesWindow(@field_win)
          Slithernix::Cdk.eraseCursesWindow(@label_win)
          Slithernix::Cdk.eraseCursesWindow(@win)
          Slithernix::Cdk.eraseCursesWindow(@shadow_win)
        end

        # This destroys an entry widget.
        def destroy
          cleanTitle

          Slithernix::Cdk.deleteCursesWindow(@field_win)
          Slithernix::Cdk.deleteCursesWindow(@label_win)
          Slithernix::Cdk.deleteCursesWindow(@shadow_win)
          Slithernix::Cdk.deleteCursesWindow(@win)

          cleanBindings(:Entry)

          Slithernix::Cdk::Screen.unregister(:Entry, self)
        end

        # This sets specific attributes of the entry field.
        def set(value, min, max, _box)
          setValue(value)
          setMin(min)
          setMax(max)
        end

        # This removes the old information in the entry field and keeps
        # the new information given.
        def setValue(new_value)
          if new_value.nil?
            @info = ''

            @left_char = 0
            @screen_col = 0
          else
            @info = new_value.clone

            setPositionToEnd
          end
        end

        def getValue
          @info
        end

        # This sets the maximum length of the string that will be accepted
        def setMax(max)
          @max = max
        end

        def getMax
          @max
        end

        # This sets the minimum length of the string that will be accepted.
        def setMin(min)
          @min = min
        end

        def getMin
          @min
        end

        # This sets the filler character to be used in the entry field.
        def setFillerChar(filler_char)
          @filler = filler_char
        end

        def getFillerChar
          @filler
        end

        # This sets the character to use when a hidden type is used.
        def setHiddenChar(_hidden_characer)
          @hidden = hidden_character
        end

        def getHiddenChar
          @hidden
        end

        # This sets the background attribute of the widget.
        def setBKattr(attrib)
          @win.wbkgd(attrib)
          @field_win.wbkgd(attrib)
          @label_win.wbkgd(attrib) unless @label_win.nil?
        end

        # This sets the attribute of the entry field.
        def setHighlight(highlight, cursor)
          @field_win.wbkgd(highlight)
          @field_attr = highlight
          Curses.curs_set(cursor)
          # FIXME(original) - if (cursor) { move the cursor to this widget }
        end

        # This sets the entry field callback function.
        def setCB(callback)
          @callbackfn = callback
        end

        def focus
          # @field_win.move(0, @screen_col)
          @field_win.refresh
        end

        def unfocus
          draw(box)
          @field_win.refresh
        end

        def position
          super(@win)
        end
      end
    end
  end
end
