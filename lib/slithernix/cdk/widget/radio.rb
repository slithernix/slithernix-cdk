# frozen_string_literal: true

require_relative 'scroller'

module Slithernix
  module Cdk
    class Widget
      class Radio < Slithernix::Cdk::Widget::Scroller
        def initialize(cdkscreen, xplace, yplace, splace, height, width, title, list, list_size, choice_char, def_item, highlight, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy

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

          # If the height is a negative value, height will be ROWS-height,
          # otherwise the height will be the given height.
          box_height = Slithernix::Cdk.set_widget_dimension(
            parent_height,
            height,
            0,
          )

          # If the width is a negative value, the width will be COLS-width,
          # otherwise the width will be the given width.
          box_width = Slithernix::Cdk.set_widget_dimension(
            parent_width,
            width,
            5,
          )

          box_width = set_title(title, box_width)

          # Set the box height.
          if @title_lines > box_height
            box_height = @title_lines + [list_size, 8].min + (2 * @border_size)
          end

          # Adjust the box width if there is a scroll bar.

          if [Slithernix::Cdk::LEFT, Slithernix::Cdk::RIGHT].include?(splace)
            box_width += 1
            @scrollbar = true
          end

          # Make sure we didn't extend beyond the dimensions of the window
          @box_width = [box_width, parent_width].min
          @box_height = [box_height, parent_height].min

          set_view_size(list_size)

          # Each item in the needs to be converted to chtype array
          widest_item = create_list(list, list_size, @box_width)
          if widest_item.positive?
            update_view_width(widest_item)
          elsif list_size.positive?
            destroy
            return nil
          end

          # Rejustify the x and y positions if we need to.
          xtmp = [xplace]
          ytmp = [yplace]
          Slithernix::Cdk.alignxy(
            cdkscreen.window,
            xtmp,
            ytmp,
            @box_width,
            @box_height,
          )

          xpos = xtmp[0]
          ypos = ytmp[0]

          # Make the radio window
          @win = Curses::Window.new(@box_height, @box_width, ypos, xpos)

          # Is the window nil?
          if @win.nil?
            destroy
            raise StandardError, 'could not create curses window'
          end

          # Turn on the keypad.
          @win.keypad(true)

          # Create the scrollbar window.
          @scrollbar_win = if splace == Slithernix::Cdk::RIGHT
                             @win.subwin(
                               max_view_size,
                               1,
                               self.screen_ypos(ypos),
                               xpos + @box_width - @border_size - 1,
                             )
                           elsif splace == Slithernix::Cdk::LEFT
                             @win.subwin(
                               max_view_size,
                               1,
                               self.screen_ypos(ypos),
                               self.screen_xpos(xpos),
                             )
                           end

          # Set the rest of the variables
          @screen = cdkscreen
          @parent = cdkscreen.window
          @scrollbar_placement = splace
          @widest_item = widest_item
          @left_char = 0
          @selected_item = 0
          @highlight = highlight
          @choice_char = choice_char.ord
          @left_box_char = '['.ord
          @right_box_char = ']'.ord
          @def_item = def_item
          @input_window = @win
          @accepts_focus = true
          @shadow = shadow

          set_current_item(0)

          # Do we need to create the shadow?
          if shadow
            @shadow_win = Curses::Window.new(box_height, box_width + 1,
                                             ypos + 1, xpos + 1)
          end

          # Setup the key bindings
          bindings.each do |from, to|
            bind(:Radio, from, :getc, to)
          end

          cdkscreen.register(:Radio, self)
        end

        # Put the cursor on the currently-selected item.
        def fix_cursor_position
          @scrollbar_placement == Slithernix::Cdk::LEFT ? 1 : 0
          ypos = self.screen_ypos(@current_item - @current_top)
          xpos = self.screen_xpos(0)

          @input_window.setpos(ypos, xpos)
          @input_window.refresh
        end

        # This actually manages the radio widget.
        def activate(actions)
          # Draw the radio list.
          draw(@box)

          if actions.nil? || actions.empty?
            while true
              fix_cursor_position
              input = getch([])

              # Inject the character into the widget.
              ret = inject(input)
              return ret if @exit_type != :EARLY_EXIT
            end
          else
            actions.each do |action|
              ret = inject(action)
              return ret if @exit_type != :EARLY_EXIT
            end
          end

          # Set the exit type and return
          set_exit_type(0)
          -1
        end

        # This injects a single character into the widget.
        def inject(input)
          pp_return = 1
          ret = -1
          complete = false

          # Set the exit type
          set_exit_type(0)

          # Draw the widget list
          draw_list(@box)

          # Check if there is a pre-process function to be called
          unless @pre_process_func.nil?
            # Call the pre-process function.
            pp_return = @pre_process_func.call(
              :Radio,
              self,
              @pre_process_data,
              input,
            )
          end

          # Should we continue?
          if pp_return != 0
            # Check for a predefined key binding.
            if check_bind(:Radio, input)
              complete = true
            else
              case input
              when Curses::KEY_UP
                self.key_up
              when Curses::KEY_DOWN
                self.key_down
              when Curses::KEY_RIGHT
                self.key_right
              when Curses::KEY_LEFT
                self.key_left
              when Curses::KEY_PPAGE
                self.key_ppage
              when Curses::KEY_NPAGE
                self.key_npage
              when Curses::KEY_HOME
                self.key_home
              when Curses::KEY_END
                self.key_end
              when '$'
                @left_char = @max_left_char
              when '|'
                @left_char = 0
              when ' '
                @selected_item = @current_item
              when Slithernix::Cdk::KEY_ESC
                set_exit_type(input)
                ret = -1
                complete = true
              when Curses::Error
                set_exit_type(input)
                complete = true
              when Slithernix::Cdk::KEY_TAB, Slithernix::Cdk::KEY_RETURN, Curses::KEY_ENTER
                set_exit_type(input)
                ret = @selected_item
                complete = true
              when Slithernix::Cdk::REFRESH
                @screen.erase
                @screen.refresh
              end
            end

            # Should we call a post-process?
            if !complete && @post_process_func
              @post_process_func.call(:Radio, self, @post_process_data, input)
            end
          end

          unless complete
            draw_list(@box)
            set_exit_type(0)
          end

          fix_cursor_position
          @return_data = ret
          ret
        end

        # This moves the radio field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@win, @scrollbar_win, @shadow_win]
          move_specific(xplace, yplace, relative, refresh_flag,
                        windows, subwidgets)
        end

        # This function draws the radio widget.
        def draw(_box)
          # Do we need to draw in the shadow?
          unless @shadow_win.nil?
            Slithernix::Cdk::Draw.draw_shadow(@shadow_win)
          end

          draw_title(@win)

          # Draw in the radio list.
          draw_list(@box)
        end

        # This redraws the radio list.
        def draw_list(box)
          scrollbar_adj = @scrollbar_placement == Slithernix::Cdk::LEFT ? 1 : 0
          screen_pos = 0

          # Draw the list
          (0...@view_size).each do |j|
            k = j + @current_top
            next unless k < @list_size

            xpos = self.screen_xpos(0)
            ypos = self.screen_ypos(j)

            screen_pos = self.screen_position(k, scrollbar_adj)

            # Draw the empty string.
            Slithernix::Cdk::Draw.write_blanks(
              @win,
              xpos,
              ypos,
              Slithernix::Cdk::HORIZONTAL,
              0,
              @box_width - @border_size,
            )

            # Draw the line.
            Slithernix::Cdk::Draw.write_chtype(
              @win,
              screen_pos >= 0 ? screen_pos : 1,
              ypos,
              @item[k],
              Slithernix::Cdk::HORIZONTAL,
              screen_pos >= 0 ? 0 : (1 - screen_pos),
              @item_len[k],
            )

            # Draw the selected choice
            xpos += scrollbar_adj
            @win.mvwaddch(ypos, xpos, @left_box_char)
            @win.mvwaddch(
              ypos,
              xpos + 1,
              k == @selected_item ? @choice_char : ' '.ord,
            )
            @win.mvwaddch(ypos, xpos + 2, @right_box_char)
          end

          # Highlight the current item
          if @has_focus
            k = @current_item
            if k < @list_size
              screen_pos = self.screen_position(k, scrollbar_adj)
              ypos = self.screen_ypos(@current_high)

              Slithernix::Cdk::Draw.write_chtype_attrib(
                @win,
                screen_pos >= 0 ? screen_pos : (1 + scrollbar_adj),
                ypos,
                @item[k],
                @highlight,
                Slithernix::Cdk::HORIZONTAL,
                screen_pos >= 0 ? 0 : (1 - screen_pos),
                @item_len[k],
              )
            end
          end

          if @scrollbar
            @toggle_pos = (@current_item * @step).floor
            @toggle_pos = [@toggle_pos, @scrollbar_win.maxy - 1].min

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

          # Box it if needed.
          Slithernix::Cdk::Draw.draw_obj_box(@win, self) if box

          fix_cursor_position
        end

        # This sets the background attribute of the widget.
        def set_background_attr(attrib)
          @win.wbkgd(attrib)
          @scrollbar_win&.wbkgd(attrib)
        end

        def destroy_info
          @item = String.new
        end

        # This function destroys the radio widget.
        def destroy
          clean_title
          destroy_info

          # Clean up the windows.
          Slithernix::Cdk.delete_curses_window(@scrollbar_win)
          Slithernix::Cdk.delete_curses_window(@shadow_win)
          Slithernix::Cdk.delete_curses_window(@win)

          # Clean up the key bindings.
          clean_bindings(:Radio)

          # Unregister this widget.
          Slithernix::Cdk::Screen.unregister(:Radio, self)
        end

        # This function erases the radio widget
        def erase
          return unless is_valid_widget?

          Slithernix::Cdk.erase_curses_window(@win)
          Slithernix::Cdk.erase_curses_window(@shadow_win)
        end

        # This sets various attributes of the radio list.
        def set(highlight, choice_char, box)
          set_highlight(highlight)
          setChoiceCHaracter(choice_char)
          set_box(box)
        end

        # This sets the radio list items.
        def set_items(list, list_size)
          widest_item = create_list(list, list_size, @box_width)
          return if widest_item <= 0

          # Clean up the display.
          (0...@view_size).each do |j|
            Slithernix::Cdk::Draw.write_blanks(
              @win,
              self.screen_xpos(0),
              self.screen_ypos(j),
              Slithernix::Cdk::HORIZONTAL,
              0,
              @box_width - @border_size,
            )
          end

          set_view_size(list_size)

          set_current_item(0)
          @left_char = 0
          @selected_item = 0

          update_view_width(widest_item)
        end

        def get_items(list)
          (0...@list_size).each do |j|
            list << Slithernix::Cdk.chtype_string_to_unformatted_string(@item[j])
          end
          @list_size
        end

        # This sets the highlight bar of the radio list.
        def set_highlight(highlight)
          @highlight = highlight
        end

        def get_highlight
          @highlight
        end

        # This sets the character to use when selecting na item in the list.
        def set_choice_character(character)
          @choice_char = character
        end

        def get_choice_character
          @choice_char
        end

        # This sets the character to use to drw the left side of the choice box
        # on the list
        def set_left_brace(character)
          @left_box_char = character
        end

        def get_left_brace
          @left_box_char
        end

        # This sets the character to use to draw the right side of the choice box
        # on the list
        def set_right_brace(character)
          @right_box_char = character
        end

        def get_right_brace
          @right_box_char
        end

        # This sets the current highlighted item of the widget
        def set_current_item(item)
          set_position(item)
          @selected_item = item
        end

        def get_current_item
          @current_item
        end

        # This sets the selected item of the widget
        def set_selected_item(item)
          @selected_item = item
        end

        def get_selected_item
          @selected_item
        end

        def focus
          draw_list(@box)
        end

        def unfocus
          draw_list(@box)
        end

        def create_list(list, list_size, box_width)
          status = false
          widest_item = 0

          if list_size >= 0
            new_list = []
            new_len = []
            new_pos = []

            # Each item in the needs to be converted to chtype array
            status = true
            box_width -= 2 + @border_size
            (0...list_size).each do |j|
              lentmp = []
              postmp = []
              new_list << Slithernix::Cdk.char_to_chtype(list[j], lentmp, postmp)
              new_len << lentmp[0]
              new_pos << postmp[0]
              if new_list[j].nil? || new_list[j].empty?
                status = false
                break
              end
              new_pos[j] =
                Slithernix::Cdk.justify_string(box_width, new_len[j],
                                               new_pos[j]) + 3
              widest_item = [widest_item, new_len[j]].max
            end
            if status
              destroy_info
              @item = new_list
              @item_len = new_len
              @item_pos = new_pos
            end
          end

          (status ? widest_item : 0)
        end

        # Determine how many characters we can shift to the right
        # before all the items have been scrolled off the screen.
        def available_width
          @box_width - (2 * @border_size) - 3
        end

        def update_view_width(widest)
          @max_left_char = if @box_width > widest
                           then 0
                           else
                             widest - self.available_width
                           end
        end

        def screen_position(n, scrollbar_adj)
          @item_pos[n] - @left_char + scrollbar_adj + @border_size
        end
      end
    end
  end
end
