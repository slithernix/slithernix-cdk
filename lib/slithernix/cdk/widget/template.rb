# frozen_string_literal: true

require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class Template < Slithernix::Cdk::Widget
        def initialize(cdkscreen, xplace, yplace, title, label, plate,
                       overlay, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          box_height = box ? 3 : 1

          return nil if plate.nil? || plate.empty?

          set_box(box)

          field_width = plate.size + (2 * @border_size)

          # Set some basic values of the template field.
          @label = []
          @label_len = 0
          @label_win = nil

          # Translate the label string to achtype array
          if label&.size&.positive?
            label_len = []
            @label = Slithernix::Cdk.char2Chtype(label, label_len, [])
            @label_len = label_len[0]
          end

          # Translate the char * overlay to a chtype array
          if overlay&.size&.positive?
            overlay_len = []
            @overlay = Slithernix::Cdk.char2Chtype(overlay, overlay_len, [])
            @overlay_len = overlay_len[0]
            @field_attr = @overlay[0] & Curses::A_ATTRIBUTES
          else
            @overlay = []
            @overlay_len = 0
            @field_attr = Curses::A_NORMAL
          end

          # Set the box width.
          box_width = field_width + @label_len + (2 * @border_size)

          old_width = box_width
          box_width = set_title(title, box_width)
          horizontal_adjust = (box_width - old_width) / 2

          box_height += @title_lines

          # Make sure we didn't extend beyond the dimensions of the window.
          box_width = [box_width, parent_width].min
          box_height = [box_height, parent_height].min
          field_width = [
            field_width,
            box_width - @label_len - (2 * @border_size)
          ].min

          # Rejustify the x and y positions if we need to.
          xtmp = [xplace]
          ytmp = [yplace]
          Slithernix::Cdk.alignxy(
            cdkscreen.window,
            xtmp,
            ytmp,
            box_width,
            box_height,
          )
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Make the template window
          @win = Curses::Window.new(box_height, box_width, ypos, xpos)

          # Is the template window nil?
          if @win.nil?
            destroy
            return nil
          end
          @win.keypad(true)

          # Make the label window.
          if label.size.positive?
            @label_win = @win.subwin(
              1,
              @label_len,
              ypos + @title_lines + @border_size,
              xpos + horizontal_adjust + @border_size,
            )
          end

          # Make the field window
          @field_win = @win.subwin(
            1,
            field_width,
            ypos + @title_lines + @border_size,
            xpos + @label_len + horizontal_adjust + @border_size,
          )
          @field_win.keypad(true)

          # Set up the info field.
          @plate_len = plate.size
          @info = String.new
          # Copy the plate to the template
          @plate = plate.clone

          # Set up the rest of the structure.
          @screen = cdkscreen
          @parent = cdkscreen.window
          @shadow_win = nil
          @field_width = field_width
          @box_height = box_height
          @box_width = box_width
          @plate_pos = 0
          @screen_pos = 0
          @info_pos = 0
          @min = 0
          @input_window = @win
          @accepts_focus = true
          @shadow = shadow
          @callbackfn = lambda do |_template, input|
            failed = false
            change = false
            moveby = false
            amount = 0
            mark = @info_pos
            @info.size

            if input == Curses::KEY_LEFT
              if mark.zero?
                failed = true
              else
                moveby = true
                amount = -1
              end
            elsif input == Curses::KEY_RIGHT
              if mark < @info.size
                moveby = true
                amount = 1
              else
                failed = true
              end
            else
              test = @info.clone
              if input == Curses::KEY_BACKSPACE
                if mark.zero?
                  failed = true
                else
                  front = @info[0...mark - 1] || ''
                  back = @info[mark..] || ''
                  test = front + back
                  change = true
                  amount = -1
                end
              elsif input == Curses::KEY_DC
                if mark < @info.size
                  front = @info[0...mark] || ''
                  back = @info[mark + 1..] || ''
                  test = front + back
                  change = true
                  amount = 0
                else
                  failed = true
                end
              elsif Slithernix::Cdk.isChar(input) && @plate_pos < @plate.size
                test[mark] = input.chr
                change = true
                amount = 1
              else
                failed = true
              end

              if change
                if validTemplate(test)
                  @info = test
                  drawField
                else
                  failed = true
                end
              end
            end

            if failed
              Slithernix::Cdk.Beep
            elsif change || moveby
              @info_pos += amount
              @plate_pos += amount
              @screen_pos += amount

              adjustCursor(amount)
            end
          end

          # Do we need to create a shadow?
          if shadow
            @shadow_win = Curses::Window.new(
              box_height,
              box_width,
              ypos + 1,
              xpos + 1,
            )
          end

          cdkscreen.register(:Template, self)
        end

        # This actually manages the tempalte widget
        def activate(actions)
          draw(@box)

          if actions.nil? || actions.empty?
            while true
              input = getch([])

              # Inject each character into the widget.
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

          # Set the exit type and return.
          set_exit_type(0)
          ret
        end

        # This injects a character into the widget.
        def inject(input)
          pp_return = 1
          complete = false
          ret = -1

          set_exit_type(0)

          # Move the cursor.
          drawField

          # Check if there is a pre-process function to be called.
          unless @pre_process_func.nil?
            pp_return = @pre_process_func.call(:Template, self,
                                               @pre_process_data, input)
          end

          # Should we continue?
          if pp_return != 0
            # Check a predefined binding
            if check_bind(:Template, input)
              complete = true
            else
              case input
              when Slithernix::Cdk::ERASE
                if @info.size.positive?
                  clean
                  drawField
                end
              when Slithernix::Cdk::CUT
                if @info.size.positive?
                  @@g_paste_buffer = @info.clone
                  clean
                  drawField
                else
                  Slithernix::Cdk.Beep
                end
              when Slithernix::Cdk::COPY
                if @info.size.positive?
                  @@g_paste_buffer = @info.clone
                else
                  Slithernix::Cdk.Beep
                end
              when Slithernix::Cdk::PASTE
                if @@g_paste_buffer.size.positive?
                  clean

                  # Start inserting each character one at a time.
                  (0...@@g_paste_buffer.size).each do |x|
                    @callbackfn.call(self, @@g_paste_buffer[x])
                  end
                  drawField
                else
                  Slithernix::Cdk.Beep
                end
              when Slithernix::Cdk::KEY_TAB, Slithernix::Cdk::KEY_RETURN, Curses::KEY_ENTER
                if @info.size < @min
                  Slithernix::Cdk.Beep
                else
                  set_exit_type(input)
                  ret = @info
                  complete = true
                end
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
                @callbackfn.call(self, input)
              end
            end

            # Should we call a post-process?
            if !complete && @post_process_func
              @post_process_func.call(
                :Template,
                self,
                @post_process_data,
                input,
              )
            end
          end

          set_exit_type(0) unless complete

          @return_data = ret
          ret
        end

        def validTemplate(input)
          pp = 0
          ip = 0
          while ip < input.size && pp < @plate.size
            newchar = input[ip]
            while pp < @plate.size && !Slithernix::Cdk::Widget::Template.isPlateChar(@plate[pp])
              pp += 1
            end
            return false if pp == @plate.size

            # Check if the input matches the plate
            if Slithernix::Cdk.digit?(newchar) && 'ACc'.include?(@plate[pp])
              return false
            end
            if !Slithernix::Cdk.digit?(newchar) && @plate[pp] == '#'
              return false
            end

            # Do we need to convert the case?
            if @plate[pp] == 'C' || @plate[pp] == 'X'
              newchar = newchar.upcase
            elsif @plate[pp] == 'c' || @plate[pp] == 'x'
              newchar = newchar.downcase
            end
            input[ip] = newchar
            ip += 1
            pp += 1
          end
          true
        end

        # Return a mixture of the plate-overlay and field-info
        def mix
          mixed_string = String.new
          plate_pos = 0
          info_pos = 0

          if @info.size.positive?
            mixed_string = String.new
            while plate_pos < @plate_len && info_pos < @info.size
              mixed_string << if Slithernix::Cdk::Widget::Template.isPlateChar(@plate[plate_pos])
                              then info_pos += 1
                                   @info[info_pos - 1]
                              else
                                @plate[plate_pos]
                              end
              plate_pos += 1
            end
          end

          mixed_string
        end

        # Return the field_info from the mixed string.
        def unmix(info)
          pos = 0
          unmixed_string = String.new

          while pos < @info.size
            if Slithernix::Cdk::Widget::Template.isPlateChar(@plate[pos])
              unmixed_string << info[pos]
            end
            pos += 1
          end

          unmixed_string
        end

        # Move the template field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@win, @label_win, @field_win, @shadow_win]
          move_specific(
            xplace,
            yplace,
            relative,
            refresh_flag,
            windows,
            [],
          )
        end

        # Draw the template widget.
        def draw(box)
          Slithernix::Cdk::Draw.draw_shadow(@shadow_win) unless @shadow_win.nil?
          Slithernix::Cdk::Draw.draw_obj_box(@win, self) if box

          draw_title(@win)

          @win.refresh

          drawField
        end

        # Draw the template field
        def drawField
          field_color = 0

          # Draw in the label and the template widget.
          unless @label_win.nil?
            Slithernix::Cdk::Draw.write_chtype(@label_win, 0, 0, @label, Slithernix::Cdk::HORIZONTAL,
                                               0, @label_len)
            @label_win.refresh
          end

          # Draw in the template
          if @overlay.size.positive?
            Slithernix::Cdk::Draw.write_chtype(@field_win, 0, 0, @overlay, Slithernix::Cdk::HORIZONTAL,
                                               0, @overlay_len)
          end

          # Adjust the cursor.
          if @info.size.positive?
            pos = 0
            (0...[@field_width, @plate.size].min).each do |x|
              unless Slithernix::Cdk::Widget::Template.isPlateChar(@plate[x]) && pos < @info.size
                next
              end

              field_color = @overlay[x] & Curses::A_ATTRIBUTES
              @field_win.mvwaddch(0, x, @info[pos].ord | field_color)
              pos += 1
            end
            # @field_win.move(0, @screen_pos)
          else
            adjustCursor(1)
          end
          @field_win.refresh
        end

        # Adjust the cursor for the template
        def adjustCursor(direction)
          while @plate_pos < [@field_width, @plate.size].min &&
                !Slithernix::Cdk::Widget::Template.isPlateChar(@plate[@plate_pos])
            @plate_pos += direction
            @screen_pos += direction
          end
          # @field_win.move(0, @screen_pos)
          @field_win.refresh
        end

        # Set the background attribute of the widget.
        def setBKattr(attrib)
          @win.wbkgd(attrib)
          @field_win.wbkgd(attrib)
          @label_win&.wbkgd(attrib)
        end

        # Destroy this widget.
        def destroy
          clean_title

          # Delete the windows
          Slithernix::Cdk.deleteCursesWindow(@field_win)
          Slithernix::Cdk.deleteCursesWindow(@label_win)
          Slithernix::Cdk.deleteCursesWindow(@shadow_win)
          Slithernix::Cdk.deleteCursesWindow(@win)

          # Clean the key bindings.
          clean_bindings(:Template)

          Slithernix::Cdk::Screen.unregister(:Template, self)
        end

        # Erase the widget.
        def erase
          return unless is_valid_widget?

          Slithernix::Cdk.eraseCursesWindow(@field_win)
          Slithernix::Cdk.eraseCursesWindow(@label_win)
          Slithernix::Cdk.eraseCursesWindow(@shadow_win)
          Slithernix::Cdk.eraseCursesWindow(@win)
        end

        # Set the value given to the template
        def set(new_value, box)
          setValue(new_value)
          set_box(box)
        end

        # Set the value given to the template.
        def setValue(new_value)
          # Just to be sure, let's make sure the new value isn't nil
          if new_value.nil?
            clean
            return
          end

          # Determine how many characters we need to copy.
          copychars = [@new_value.size, @field_width, @plate.size].min

          @info = new_value[0...copychars]

          # Use the function which handles the input of the characters.
          (0...new_value.size).each do |x|
            @callbackfn.call(self, new_value[x].ord)
          end
        end

        def getValue
          @info
        end

        # Set the minimum number of characters to enter into the widget.
        def setMin(min)
          @min = min if min >= 0
        end

        def getMin
          @min
        end

        # Erase the information in the template widget.
        def clean
          @info = String.new
          @screen_pos = 0
          @info_pos = 0
          @plaste_pos = 0
        end

        # Set the callback function for the widget.
        def setCB(callback)
          @callbackfn = callback
        end

        def focus
          draw(@box)
        end

        def unfocus
          draw(@box)
        end

        def self.isPlateChar(c)
          '#ACcMXz'.include?(c.chr)
        end

        def position
          super(@win)
        end
      end
    end
  end
end
