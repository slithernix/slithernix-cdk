# frozen_string_literal: true

require_relative 'scroller'

module Slithernix
  module Cdk
    class Widget
      class Scroll < Slithernix::Cdk::Widget::Scroller
        attr_reader :item, :list_size, :current_item, :highlight

        def initialize(cdkscreen, xplace, yplace, splace, height, width, title, list, list_size, numbers, highlight, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          xpos = xplace
          ypos = yplace
          scroll_adjust = 0
          bindings = {
            'g' => Curses::KEY_HOME,
            '1' => Curses::KEY_HOME,
            'G' => Curses::KEY_END,
            '<' => Curses::KEY_HOME,
            '>' => Curses::KEY_END
          }

          bindings[Slithernix::Cdk::BACKCHAR] = Curses::KEY_PPAGE
          bindings[Slithernix::Cdk::FORCHAR]  = Curses::KEY_NPAGE

          set_box(box)

          # If the height is a negative value, the height will be ROWS-height,
          # otherwise the height will be the given height
          box_height = Slithernix::Cdk.set_widget_dimension(
            parent_height,
            height,
            0,
          )

          # If the width is a negative value, the width will be COLS-width,
          # otherwise the width will be the given width
          box_width = Slithernix::Cdk.set_widget_dimension(
            parent_width,
            width,
            0,
          )

          box_width = set_title(title, box_width)

          # Set the box height.
          if @title_lines > box_height
            box_height = @title_lines + [list_size, 8].min + (2 * @border_size)
          end

          # Adjust the box width if there is a scroll bar
          if [Slithernix::Cdk::LEFT, Slithernix::Cdk::RIGHT].include?(splace)
            @scrollbar = true
            box_width += 1
          else
            @scrollbar = false
          end

          # Make sure we didn't extend beyond the dimensions of the window.
          @box_width = box_width
          @box_width = parent_width - scroll_adjust if box_width > parent_width
          @box_height = [box_height, parent_height].min

          set_view_size(list_size)

          # Rejustify the x and y positions if we need to.
          xtmp = [xpos]
          ytmp = [ypos]
          Slithernix::Cdk.alignxy(
            cdkscreen.window,
            xtmp,
            ytmp,
            @box_width,
            @box_height,
          )
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Make the scrolling window
          @win = Curses::Window.new(@box_height, @box_width, ypos, xpos)

          # Is the scrolling window null?
          return StandardError, 'could not create curses window' if @win.nil?

          # Turn the keypad on for the window
          @win.keypad(true)

          xp = screen_xpos(xpos)

          if splace == Slithernix::Cdk::RIGHT
            xp = xpos + box_width - @border_size - 1
          end

          # Create the scrollbar window.
          @scrollbar_win = @win.subwin(
            max_view_size,
            1,
            screen_ypos(ypos),
            xp
          )

          # create the list window
          @list_win = @win.subwin(
            max_view_size,
            box_width - (2 * @border_size) - scroll_adjust,
            screen_ypos(ypos),
            screen_xpos(xpos) + (splace == Slithernix::Cdk::LEFT ? 1 : 0),
          )

          # Set the rest of the variables
          @screen = cdkscreen
          @parent = cdkscreen.window
          @shadow_win = nil
          @scrollbar_placement = splace
          @max_left_char = 0
          @left_char = 0
          @highlight = highlight
          # initExitType (scrollp);
          @accepts_focus = true
          @input_window = @win
          @shadow = shadow

          set_position(0)

          # Create the scrolling list item list and needed variables.
          return nil if create_item_list(numbers, list, list_size) <= 0

          # Do we need to create a shadow?
          if shadow
            @shadow_win = Curses::Window.new(
              @box_height,
              box_width,
              ypos + 1,
              xpos + 1,
            )
          end

          # Set up the key bindings.
          bindings.each do |from, to|
            # self.bind(:SCROLL, from, getc_lambda, to)
            bind(:Scroll, from, :getc, to)
          end

          cdkscreen.register(:Scroll, self)
        end

        def position
          super(@win)
        end

        # Put the cursor on the currently-selected item's row.
        def fix_cursor_position
          @scrollbar_placement == LEFT ? 1 : 0
          ypos = screen_ypos(@current_item - @current_top)
          xpos = screen_xpos(0)

          @input_window.setpos(ypos, xpos)
          @input_window.refresh
        end

        # This actually does all the 'real' work of managing the scrolling list.
        def activate(actions)
          # Draw the scrolling list
          draw(@box)

          if actions.nil? || actions.empty?
            loop do
              fix_cursor_position
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

          # Set the exit type for the widget and return
          set_exit_type(0)
          -1
        end

        # This injects a single character into the widget.
        def inject(input)
          pp_return = 1
          ret = -1
          complete = false

          # Set the exit type for the widget.
          set_exit_type(0)

          # Draw the scrolling list
          draw_list(@box)

          # Check if there is a pre-process function to be called.
          unless @pre_process_func.nil?
            pp_return = @pre_process_func.call(
              :Scroll,
              self,
              @pre_process_data,
              input,
            )
          end

          # Should we continue?
          if pp_return != 0
            # Check for a predefined key binding.
            if check_bind(:Scroll, input) == false
              case input
              when Curses::KEY_UP
                key_up
              when Curses::KEY_DOWN
                key_down
              when Curses::KEY_RIGHT
                key_right
              when Curses::KEY_LEFT
                key_left
              when Curses::KEY_PPAGE
                key_ppage
              when Curses::KEY_NPAGE
                key_npage
              when Curses::KEY_HOME
                key_home
              when Curses::KEY_END
                key_end
              when '$'
                @left_char = @max_left_char
              when '|'
                @left_char = 0
              when Slithernix::Cdk::KEY_ESC
                set_exit_type(input)
                complete = true
              when Curses::Error
                set_exit_type(input)
                complete = true
              when Slithernix::Cdk::REFRESH
                @screen.erase
                @screen.refresh
              when Slithernix::Cdk::KEY_TAB, Curses::KEY_ENTER, Slithernix::Cdk::KEY_RETURN
                set_exit_type(input)
                ret = @current_item
                complete = true
              end
            else
              complete = true
            end

            if !complete && @post_process_func
              @post_process_func.call(:Scroll, self, @post_process_data, input)
            end
          end

          unless complete
            draw_list(@box)
            set_exit_type(0)
          end

          fix_cursor_position
          @result_data = ret

          # return ret != -1
          ret
        end

        def get_current_top
          @current_top
        end

        def set_current_top(item)
          if item.negative?
            item = 0
          elsif item > @max_top_item
            item = @max_top_item
          end
          @current_top = item

          set_position(item)
        end

        # This moves the scroll field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@win, @list_win, @shadow_win, @scrollbar_win]
          move_specific(
            xplace,
            yplace,
            relative,
            refresh_flag,
            windows,
            []
          )
        end

        # This function draws the scrolling list widget.
        def draw(box)
          # Draw in the shadow if we need to.
          unless @shadow_win.nil?
            Slithernix::Cdk::Draw.draw_shadow(@shadow_win)
          end

          draw_title(@win)

          # Draw in the scrolling list items.
          draw_list(box)
        end

        def draw_current
          # Rehighlight the current menu item.
          screen_pos = @item_pos[@current_item] - @left_char
          highlight = has_focus ? @highlight : Curses::A_NORMAL

          Slithernix::Cdk::Draw.write_chtype_attrib(
            @list_win,
            [screen_pos, 0].max,
            @current_high,
            @item[@current_item],
            highlight,
            Slithernix::Cdk::HORIZONTAL,
            screen_pos >= 0 ? 0 : (1 - screen_pos),
            @item_len[@current_item],
          )
        end

        def draw_list(box)
          # If the list is empty, don't draw anything.
          if @list_size.positive?
            # Redraw the list
            (0...@view_size).each do |j|
              k = j + @current_top

              Slithernix::Cdk::Draw.write_blanks(
                @list_win,
                0,
                j,
                Slithernix::Cdk::HORIZONTAL,
                0,
                @box_width - (2 * @border_size),
              )

              # Draw the elements in the scrolling list.
              next unless k < @list_size

              screen_pos = @item_pos[k] - @left_char
              ypos = j

              # Write in the correct line.
              Slithernix::Cdk::Draw.write_chtype(
                @list_win,
                screen_pos >= 0 ? screen_pos : 1,
                ypos,
                @item[k],
                Slithernix::Cdk::HORIZONTAL,
                screen_pos >= 0 ? 0 : (1 - screen_pos),
                @item_len[k],
              )
            end

            draw_current

            # Determine where the toggle is supposed to be.
            unless @scrollbar_win.nil?
              @toggle_pos = (@current_item * @step).floor

              # Make sure the toggle button doesn't go out of bounds.

              if @toggle_pos >= @scrollbar_win.maxy
                @toggle_pos = @scrollbar_win.maxy - 1
              end

              # Draw the scrollbar
              @scrollbar_win.mvwvline(
                0,
                0,
                Slithernix::Cdk::ACS_CKBOARD,
                @scrollbar_win.maxy,
              )

              @scrollbar_win.mvwvline(
                @toggle_pos,
                0,
                ' '.ord | Curses::A_REVERSE,
                @toggle_size,
              )
            end
          end

          # Box it if needed.
          Slithernix::Cdk::Draw.draw_obj_box(@win, self) if box

          # Refresh the window
          @win.refresh
        end

        # This sets the background attribute of the widget.
        def set_background_attr(attrib)
          @win&.wbkgd(attrib)
          @list_win&.wbkgd(attrib)
          @scrollbar_win&.wbkgd(attrib)
        end

        def destroy
          clean_title

          # Clean up the windows.
          Slithernix::Cdk.delete_curses_window(@scrollbar_win)
          Slithernix::Cdk.delete_curses_window(@shadow_win)
          Slithernix::Cdk.delete_curses_window(@list_win)
          Slithernix::Cdk.delete_curses_window(@win)

          # Clean the key bindings.
          clean_bindings(:Scroll)

          # Unregister this widget
          Slithernix::Cdk::Screen.unregister(:Scroll, self)
        end

        # This function erases the scrolling list from the screen.
        def erase
          Slithernix::Cdk.erase_curses_window(@win)
          Slithernix::Cdk.erase_curses_window(@shadow_win)
        end

        def alloc_list_arrays(old_size, new_size)
          result = true
          new_list = Array.new(new_size)
          new_len = Array.new(new_size)
          new_pos = Array.new(new_size)

          (0...old_size).each do |n|
            new_list[n] = @item[n]
            new_len[n] = @item_len[n]
            new_pos[n] = @item_pos[n]
          end

          @item = new_list
          @item_len = new_len
          @item_pos = new_pos

          result
        end

        def alloc_list_item(which, _work, _used, number, value)
          value = format('%4d. %s', number, value) if number.positive?

          item_len = []
          item_pos = []
          @item[which] = Slithernix::Cdk.char_to_chtype(
            value,
            item_len,
            item_pos,
          )
          @item_len[which] = item_len[0]
          @item_pos[which] = item_pos[0]

          @item_pos[which] = Slithernix::Cdk.justify_string(
            @box_width,
            @item_len[which],
            @item_pos[which],
          )

          true
        end

        # This function creates the scrolling list information and sets up the
        # needed variables for the scrolling list to work correctly.
        def create_item_list(numbers, list, list_size)
          status = 0
          if list_size.positive?
            widest_item = 0
            have = 0
            temp = String.new
            if alloc_list_arrays(0, list_size)
              # Create the items in the scrolling list.
              status = 1
              (0...list_size).each do |x|
                number = numbers ? x + 1 : 0
                unless alloc_list_item(x, temp, have, number, list[x])
                  status = 0
                  break
                end

                widest_item = [@item_len[x], widest_item].max
              end

              if status
                update_view_width(widest_item)

                # Keep the boolean flag 'numbers'
                @numbers = numbers
              end
            end
          else
            status = 1 # null list is ok - for a while
          end

          status
        end

        # This sets certain attributes of the scrolling list.
        def set(list, list_size, numbers, highlight, box)
          set_items(list, list_size, numbers)
          set_highlight(highlight)
          set_box(box)
        end

        # This sets the scrolling list items
        def set_items(list, list_size, numbers)
          return if create_item_list(numbers, list, list_size) <= 0

          # Clean up the display.
          (0...@view_size).each do |x|
            Slithernix::Cdk::Draw.write_blanks(
              @win,
              1,
              x,
              Slithernix::Cdk::HORIZONTAL,
              0,
              @box_width - 2
            )
          end

          set_view_size(list_size)
          set_position(0)
          @left_char = 0
        end

        def get_items(list)
          (0...@list_size).each do |x|
            list << Slithernix::Cdk.chtype_string_to_unformatted_string(@item[x])
          end

          @list_size
        end

        # This sets the highlight of the scrolling list.
        def set_highlight(highlight)
          @highlight = highlight
        end

        def get_highlight(_highlight)
          @highlight
        end

        # Resequence the numbers after an insertion/deletion.
        def resequence
          return unless @numbers

          (0...@list_size).each do |j|
            target = @item[j]

            source = format('%4d. %s', j + 1, '')

            k = 0
            while k < source.size
              # handle deletions that change the length of number
              if source[k] == '.' && target[k] != '.'
                source = source[0...k] + source[k + 1..]
              end

              target[k] &= Curses::A_ATTRIBUTES
              target[k] |= source[k].ord
              k += 1
            end
          end
        end

        def insert_list_item(item)
          @item = @item[0..item] + @item[item..]
          @item_len = @item_len[0..item] + @item_len[item..]
          @item_pos = @item_pos[0..item] + @item_pos[item..]
          true
        end

        # This adds a single item to a scrolling list, at the end of the list.
        def add_item(item)
          item_number = @list_size
          widest_item = self.widest_item
          temp = String.new
          have = 0

          if alloc_list_arrays(
            @list_size,
            @list_size + 1
          ) && alloc_list_item(
            item_number,
            temp,
            have,
            @numbers ? item_number + 1 : 0,
            item,
          )
            # Determine the size of the widest item.
            widest_item = [@item_len[item_number], widest_item].max

            update_view_width(widest_item)
            set_view_size(@list_size + 1)
          end
        end

        # This adds a single item to a scrolling list before the current item
        def insert_item(item)
          widest_item = self.widest_item
          temp = String.new
          have = 0

          if alloc_list_arrays(
            @list_size,
            @list_size + 1
          ) && insert_list_item(
            @current_item
          ) && alloc_list_item(
            @current_item,
            temp,
            have,
            @numbers ? @current_item + 1 : 0,
            item
          )
            # Determine the size of the widest item.
            widest_item = [@item_len[@current_item], widest_item].max

            update_view_width(widest_item)
            set_view_size(@list_size + 1)
            resequence
          end
        end

        # This removes a single item from a scrolling list.
        def delete_item(position)
          return unless position >= 0 && position < @list_size

          # Adjust the list
          @item = @item[0...position] + @item[position + 1..]
          @item_len = @item_len[0...position] + @item_len[position + 1..]
          @item_pos = @item_pos[0...position] + @item_pos[position + 1..]

          set_view_size(@list_size - 1)

          resequence if @list_size.positive?

          if @list_size < max_view_size
            @win.erase # force the next redraw to be complete
          end

          # do this to update the view size, etc
          set_position(@current_item)
        end

        def focus
          draw_current
          @list_win.refresh
        end

        def unfocus
          draw_current
          @list_win.refresh
        end
      end
    end
  end
end
