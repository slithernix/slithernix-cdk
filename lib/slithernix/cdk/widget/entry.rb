# frozen_string_literal: true

require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class Entry < Slithernix::Cdk::Widget
        attr_accessor :info, :left_char, :screen_col
        attr_reader :win, :box_height, :box_width, :max, :field_width, :min

        def initialize(cdkscreen, xplace, yplace, title, label, field_attr, filler, disp_type, f_width, min, max, box, shadow)
          super()
          Curses.curs_set(1)
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          field_width = f_width
          xpos = xplace
          ypos = yplace

          set_box(box)
          box_height = (@border_size * 2) + 1

          # If the field_width is a negative value, the field_width will be
          # COLS-field_width, otherwise the field_width will be the given width.
          field_width = Slithernix::Cdk.set_widget_dimension(
            parent_width,
            field_width,
            0
          )
          box_width = field_width + (2 * @border_size)

          # Set some basic values of the entry field.
          @label = 0
          @label_len = 0
          @label_win = nil

          # Translate the label string to a chtype array
          if label&.size&.positive?
            label_len = [@label_len]
            @label = Slithernix::Cdk.char_to_chtype(label, label_len, [])
            @label_len = label_len[0]
            box_width += @label_len
          end

          old_width = box_width
          box_width = set_title(title, box_width)
          horizontal_adjust = (box_width - old_width) / 2

          box_height += @title_lines

          # Make sure we didn't extend beyond the dimensinos of the window.
          box_width = [box_width, parent_width].min
          box_height = [box_height, parent_height].min
          field_width = [
            field_width,
            box_width - @label_len - (2 * @border_size),
          ].min

          # Rejustify the x and y positions if we need to.
          xtmp = [xpos]
          ytmp = [ypos]
          Slithernix::Cdk.alignxy(
            cdkscreen.window,
            xtmp,
            ytmp,
            box_width,
            box_height,
          )
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
          @field_win = @win.subwin(
            1,
            field_width,
            ypos + @title_lines + @border_size,
            xpos + @label_len + horizontal_adjust + @border_size,
          )

          if @field_win.nil?
            destroy
            return nil
          end
          @field_win.keypad(true)

          # make the label win, if we need to
          if label&.size&.positive?
            @label_win = @win.subwin(
              1,
              @label_len,
              ypos + @title_lines + @border_size,
              xpos + horizontal_adjust + @border_size,
            )
          end

          # clean_char (entry->info, max + 3, '\0');
          @info = String.new
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
            plainchar = Slithernix::Cdk::Display.filter_by_display_type(
              entry,
              character
            )

            return Slithernix::Cdk.beep if invalid_input?(entry, plainchar)

            update_entry(entry, plainchar)
            entry.draw_field
          end

          if shadow
            @shadow_win = cdkscreen.window.subwin(
              box_height,
              box_width,
              ypos + 1,
              xpos + 1,
            )
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

          if actions.nil? || actions.empty?
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

        def set_position_to_end
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
          set_exit_type(0)

          # Refresh the widget field. This seems useless?
          # self.draw_field

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
            if check_bind(:Entry, input)
              complete = true
            else
              curr_pos = @screen_col + @left_char

              case input
              when Curses::KEY_UP, Curses::KEY_DOWN
                Slithernix::Cdk.beep
              when Curses::KEY_HOME
                @left_char = 0
                @screen_col = 0
                draw_field
              when Slithernix::Cdk::TRANSPOSE
                if curr_pos >= @info.size - 1
                  Slithernix::Cdk.beep
                else
                  holder = @info[curr_pos]
                  @info[curr_pos] = @info[curr_pos + 1]
                  @info[curr_pos + 1] = holder
                  draw_field
                end
              when Curses::KEY_END
                set_position_to_end
                draw_field
              when Curses::KEY_LEFT
                if curr_pos <= 0
                  Slithernix::Cdk.beep
                elsif @screen_col.zero?
                  # Scroll left.
                  @left_char -= 1
                  draw_field
                else
                  @screen_col -= 1
                  @field_win.setpos(0, @screen_col)
                end
              when Curses::KEY_RIGHT
                if curr_pos >= @info.size
                  Slithernix::Cdk.beep
                elsif @screen_col == @field_width - 1
                  # Scroll to the right.
                  @left_char += 1
                  draw_field
                else
                  # Move right.
                  @screen_col += 1
                  @field_win.setpos(0, @screen_col)
                end
              when Curses::KEY_BACKSPACE, Curses::KEY_DC
                if @disp_type == :VIEWONLY
                  Slithernix::Cdk.beep
                else
                  success = false
                  curr_pos -= 1 if input == Curses::KEY_BACKSPACE

                  if curr_pos >= 0 && @info.size.positive?
                    if curr_pos < @info.size
                      @info = @info[0...curr_pos] + @info[curr_pos + 1..]
                      success = true
                    elsif input == Curses::KEY_BACKSPACE
                      @info = @info[0...-1]
                      success = true
                    end
                  end

                  if success
                    if input == Curses::KEY_BACKSPACE
                      if @screen_col.positive?
                        @screen_col -= 1
                      else
                        @left_char -= 1
                      end
                    end
                    draw_field
                  else
                    Slithernix::Cdk.beep
                  end
                end
              when Slithernix::Cdk::ERASE
                unless @info.empty?
                  clean
                  draw_field
                end
              when Slithernix::Cdk::CUT
                if @info.empty?
                  Slithernix::Cdk.beep
                else
                  @@g_paste_buffer = @info.clone
                  clean
                  draw_field
                end
              when Slithernix::Cdk::COPY
                if @info.empty?
                  Slithernix::Cdk.beep
                else
                  @@g_paste_buffer = @info.clone
                end
              when Slithernix::Cdk::PASTE
                if @@g_paste_buffer&.empty?
                  Slithernix::Cdk.beep
                else
                  set_value(@@g_paste_buffer)
                  draw_field
                end
              when Slithernix::Cdk::KEY_TAB, Slithernix::Cdk::KEY_RETURN, Curses::KEY_ENTER
                if @info.size >= @min
                  set_exit_type(input)
                  ret = @info
                  complete = true
                else
                  Slithernix::Cdk.beep
                end
              when Slithernix::Cdk::KEY_ESC, Curses::Error
                set_exit_type(input)
                complete = true
              when Slithernix::Cdk::REFRESH
                @screen.erase
                @screen.refresh
              else
                @callbackfn.call(self, input)
              end
            end

            if !complete && @post_process_func
              @post_process_func.call(:Entry, self, @post_process_data, input)
            end
          end

          set_exit_type(0) unless complete

          @result_data = ret
          ret
        end

        # This moves the entry field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@win, @field_win, @label_win, @shadow_win]
          move_specific(
            xplace,
            yplace,
            relative,
            refresh_flag,
            windows,
            [],
          )
        end

        # This erases the information in the entry field and redraws
        # a clean and empty entry field.
        def clean
          width = @field_width

          @info = String.new

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
          unless @shadow_win.nil?
            Slithernix::Cdk::Draw.draw_shadow(@shadow_win)
          end

          # Box the widget if asked.
          Slithernix::Cdk::Draw.draw_obj_box(@win, self) if box

          draw_title(@win)

          @win.refresh

          # Draw in the label to the widget.
          unless @label_win.nil?
            Slithernix::Cdk::Draw.write_chtype(
              @label_win,
              0,
              0,
              @label,
              Slithernix::Cdk::HORIZONTAL,
              0,
              @label_len,
            )
            @label_win.refresh
          end

          draw_field
        end

        def draw_field
          # Draw in the filler characters.
          @field_win.mvwhline(0, 0, @filler.ord, @field_width)

          # If there is information in the field then draw it in.
          if @info&.size&.positive?
            # Redraw the field.
            if Slithernix::Cdk::Display.is_hidden_display_type?(@disp_type)
              (@left_char...@info.size).each do |x|
                @field_win.mvwaddch(
                  0,
                  x - @left_char,
                  @hidden,
                )
              end
            else
              (@left_char...@info.size).each do |x|
                @field_win.mvwaddch(
                  0,
                  x - @left_char,
                  @info[x].ord | @field_attr,
                )
              end
            end
            @field_win.setpos(0, @screen_col)
          end

          # This makes sure the cursor is at the beginning of the entry field
          # when nothing is in the buffer.
          @field_win.setpos(0, 0) if @info&.size&.zero?
          @field_win.refresh
        end

        # This erases an entry widget from the screen.
        def erase
          return unless is_valid_widget?

          Slithernix::Cdk.erase_curses_window(@field_win)
          Slithernix::Cdk.erase_curses_window(@label_win)
          Slithernix::Cdk.erase_curses_window(@win)
          Slithernix::Cdk.erase_curses_window(@shadow_win)
        end

        # This destroys an entry widget.
        def destroy
          clean_title

          Slithernix::Cdk.delete_curses_window(@field_win)
          Slithernix::Cdk.delete_curses_window(@label_win)
          Slithernix::Cdk.delete_curses_window(@shadow_win)
          Slithernix::Cdk.delete_curses_window(@win)

          clean_bindings(:Entry)

          Slithernix::Cdk::Screen.unregister(:Entry, self)
        end

        # This sets specific attributes of the entry field.
        def set(value, min, max, _box)
          set_value(value)
          set_min(min)
          set_max(max)
        end

        # This removes the old information in the entry field and keeps
        # the new information given.
        def set_value(new_value)
          if new_value.nil?
            @info = String.new

            @left_char = 0
            @screen_col = 0
          else
            @info = new_value.clone

            set_position_to_end
          end
        end

        def get_value
          @info
        end

        # This sets the maximum length of the string that will be accepted
        def set_max(max)
          @max = max
        end

        def get_max
          @max
        end

        # This sets the minimum length of the string that will be accepted.
        def set_min(min)
          @min = min
        end

        def get_min
          @min
        end

        # This sets the filler character to be used in the entry field.
        def set_filler_char(filler_char)
          @filler = filler_char
        end

        def get_filler_char
          @filler
        end

        # This sets the character to use when a hidden type is used.
        def set_hidden_char(hidden_character)
          @hidden = hidden_character
        end

        def get_hidden_char
          @hidden
        end

        def set_background_attr(attrib)
          @win.wbkgd(attrib)
          @field_win.wbkgd(attrib)
          @label_win&.wbkgd(attrib)
        end

        def set_highlight(highlight, cursor)
          @field_win.wbkgd(highlight)
          @field_attr = highlight
          Curses.curs_set(cursor)
          # FIXME(original) - if (cursor) { move the cursor to this widget }
        end

        # This sets the entry field callback function.
        def set_callback(callback)
          @callbackfn = callback
        end

        def focus
          @field_win.setpos(0, @screen_col)
          @field_win.refresh
        end

        def unfocus
          draw(box)
          @field_win.refresh
        end

        def position
          super(@win)
        end

        def invalid_input?(entry, plainchar)
          plainchar == Curses::Error || entry.info.size >= entry.max
        end

        def update_entry(entry, plainchar)
          if entry.screen_col == entry.field_width - 1
            append_character(entry, plainchar)
          else
            insert_character(entry, plainchar)
          end
        end

        def append_character(entry, plainchar)
          entry.info << plainchar
          entry.left_char += 1 if entry.info.size < entry.max
        end

        def insert_character(entry, plainchar)
          insert_position = entry.screen_col + entry.left_char
          front = entry.info[0...insert_position] || ''
          back = entry.info[insert_position..] || ''
          entry.info = front + plainchar.chr + back
          entry.screen_col += 1
        end
      end
    end
  end
end
