# frozen_string_literal: true

require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class ItemList < Slithernix::Cdk::Widget
        def initialize(cdkscreen, xplace, yplace, title, label, item, count, default_item, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy

          unless create_list(item, count)
            destroy
            return nil
          end

          set_box(box)
          box_height = (@border_size * 2) + 1

          # Set some basic values of the item list
          @label = String.new
          @label_len = 0
          @label_win = nil

          # Translate the label string to a chtype array
          if label&.size&.positive?
            label_len = []
            @label = Slithernix::Cdk.char_to_chtype(label, label_len, [])
            @label_len = label_len[0]
          end

          # Set the box width. Allow an extra char in field width for cursor
          field_width = maximum_field_width + 1
          box_width = field_width + @label_len + (2 * @border_size)
          box_width = set_title(title, box_width)
          box_height += @title_lines

          # Make sure we didn't extend beyond the dimensions of the window
          @box_width = [box_width, parent_width].min
          @box_height = [box_height, parent_height].min
          update_field_width

          # Rejustify the x and y positions if we need to.
          xtmp = [xplace]
          ytmp = [yplace]
          Slithernix::Cdk.alignxy(cdkscreen.window, xtmp, ytmp, box_width,
                                  box_height)
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Make the window.
          @win = Curses::Window.new(box_height, box_width, ypos, xpos)
          if @win.nil?
            destroy
            return nil
          end

          # Make the label window if there was a label.
          if @label.size.positive?
            @label_win = @win.subwin(
              1,
              @label_len,
              ypos + @border_size + @title_lines,
              xpos + @border_size
            )

            if @label_win.nil?
              destroy
              return nil
            end
          end

          @win.keypad(true)

          # Make the field window.
          unless create_field_win(
            ypos + @border_size + @title_lines,
            xpos + @label_len + @border_size
          )
            destroy
            return nil
          end

          # Set up the rest of the structure
          @screen = cdkscreen
          @parent = cdkscreen.window
          @shadow_win = nil
          @accepts_focus = true
          @shadow = shadow

          # Set the default item.
          if default_item >= 0 && default_item < @list_size
            @current_item = default_item
            @default_item = default_item
          else
            @current_item = 0
            @default_item = 0
          end

          # Do we want a shadow?
          if shadow
            @shadow_win = Curses::Window.new(
              box_height,
              box_width,
              ypos + 1, xpos + 1
            )

            if @shadow_win.nil?
              destroy
              return nil
            end
          end

          # Register this baby.
          cdkscreen.register(:ItemList, self)
        end

        # This allows the user to play with the widget.
        def activate(actions)
          ret = -1

          # Draw the widget.
          draw(@box)
          draw_field(true)

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
              return ret if @exit_type != :EARLY_EXIT
            end
          end

          # Set the exit type and exit.
          set_exit_type(0)
          ret
        end

        # This injects a single character into the widget.
        def inject(input)
          pp_return = 1
          ret = -1
          complete = false

          # Set the exit type.
          set_exit_type(0)

          # Draw the widget field
          draw_field(true)

          # Check if there is a pre-process function to be called.
          unless @pre_process_func.nil?
            pp_return = @pre_process_func.call(:ItemList, self,
                                               @pre_process_data, input)
          end

          # Should we continue?
          if pp_return != 0
            # Check a predefined binding.
            if check_bind(:ItemList, input)
              complete = true
            else
              case input
              when Curses::KEY_UP, Curses::KEY_RIGHT, ' ', '+', 'n'
                if @current_item < @list_size - 1
                  @current_item += 1
                else
                  @current_item = 0
                end
              when Curses::KEY_DOWN, Curses::KEY_LEFT, '-', 'p'
                if @current_item.positive?
                  @current_item -= 1
                else
                  @current_item = @list_size - 1
                end
              when 'd', 'D'
                @current_item = @default_item
              when '0'
                @current_item = 0
              when '$'
                @current_item = @list_size - 1
              when Slithernix::Cdk::KEY_ESC
                set_exit_type(input)
                complete = true
              when Curses::Error
                set_exit_type(input)
                complete = true
              when Slithernix::Cdk::KEY_TAB, Slithernix::Cdk::KEY_RETURN, Curses::KEY_ENTER
                set_exit_type(input)
                ret = @current_item
                complete = true
              when Slithernix::Cdk::REFRESH
                @screen.erase
                @screen.refresh
              else
                Slithernix::Cdk.beep
              end
            end

            # Should we call a post-process?
            if !complete && @post_process_func
              @post_process_func.call(
                :ItemList,
                self,
                @post_process_data,
                input
              )
            end
          end

          unless complete
            draw_field(true)
            set_exit_type(0)
          end

          @result_data = ret
          ret
        end

        # This moves the itemlist field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@win, @field_win, @label_win, @shadow_win]
          move_specific(
            xplace,
            yplace,
            relative,
            refresh_flag,
            windows,
            []
          )
        end

        # This draws the widget on the screen.
        def draw(box)
          # Did we ask for a shadow?
          unless @shadow_win.nil?
            Slithernix::Cdk::Draw.draw_shadow(@shadow_win)
          end

          draw_title(@win)

          # Draw in the label to the widget.
          unless @label_win.nil?
            Slithernix::Cdk::Draw.write_chtype(
              @label_win,
              0,
              0,
              @label,
              Slithernix::Cdk::HORIZONTAL,
              0,
              @label.size
            )
          end

          # Box the widget if asked.
          Slithernix::Cdk::Draw.draw_obj_box(@win, self) if box

          @win.refresh

          # Draw in the field.
          draw_field(false)
        end

        # This sets the background attribute of the widget
        def set_background_attr(attrib)
          @win.wbkgd(attrib)
          @field_win.wbkgd(attrib)
          @label_win&.wbkgd(attrib)
        end

        # This function draws the contents of the field.
        def draw_field(highlight)
          # Declare local vars.
          current_item = @current_item

          # Determine how much we have to draw.
          len = [@item_len[current_item], @field_width].min

          # Erase the field window.
          @field_win.erase

          # Draw in the current item in the field.
          (0...len).each do |x|
            c = @item[current_item][x]

            c = c.ord | Curses::A_REVERSE if highlight

            @field_win.mvwaddch(0, x + @item_pos[current_item], c)
          end

          # Redraw the field window.
          @field_win.refresh
        end

        # This function removes the widget from the screen.
        def erase
          return unless is_valid_widget?

          Slithernix::Cdk.erase_curses_window(@field_win)
          Slithernix::Cdk.erase_curses_window(@label_win)
          Slithernix::Cdk.erase_curses_window(@win)
          Slithernix::Cdk.erase_curses_window(@shadow_win)
        end

        def destroy_info
          @list_size = 0
          @item = String.new
        end

        # This function destroys the widget and all the memory it used.
        def destroy
          clean_title
          destroy_info

          # Delete the windows
          Slithernix::Cdk.delete_curses_window(@field_win)
          Slithernix::Cdk.delete_curses_window(@label_win)
          Slithernix::Cdk.delete_curses_window(@shadow_win)
          Slithernix::Cdk.delete_curses_window(@win)

          # Clean the key bindings.
          clean_bindings(:ItemList)

          Slithernix::Cdk::Screen.unregister(:ItemList, self)
        end

        # This sets multiple attributes of the widget.
        def set(list, count, current, box)
          set_values(list, count, current)
          set_box(box)
        end

        # This function sets the contents of the list
        def set_values(item, count, default_item)
          return unless create_list(item, count)

          old_width = @field_width

          # Set the default item.
          if default_item >= 0 && default_item < @list_size
            @current_item = default_item
            @default_item = default_item
          end

          # This will not resize the outer windows but can still make a usable
          # field width if the title made the outer window wide enough
          update_field_width
          if @field_width > old_width
            create_field_win(@field_win.begy, @field_win.begx)
          end

          # Draw the field.
          erase
          draw(@box)
        end

        def get_values(size)
          size << @list_size
          @item
        end

        # This sets the default/current item of the itemlist
        def set_current_item(current_item)
          # Set the default item.
          return unless current_item >= 0 && current_item < @list_size

          @current_item = current_item
        end

        def get_current_item
          @current_item
        end

        # This sets the default item in the list.
        def set_default_item(default_item)
          # Make sure the item is in the correct range.
          @default_item = if default_item.negative?
                            0
                          elsif default_item >= @list_size
                            @list_size - 1
                          else
                            default_item
                          end
        end

        def get_default_item
          @default_item
        end

        def focus
          draw_field(true)
        end

        def unfocus
          draw_field(false)
        end

        def create_list(item, count)
          status = false
          new_items = []
          new_pos = []
          new_len = []
          if count >= 0
            field_width = 0

            # Go through the list and determine the widest item.
            status = true
            (0...count).each do |x|
              # Copy the item to the list.
              lentmp = []
              postmp = []
              new_items << Slithernix::Cdk.char_to_chtype(
                item[x],
                lentmp,
                postmp
              )
              new_len << lentmp[0]
              new_pos << postmp[0]
              if (new_items[0])&.size&.zero?
                status = false
                break
              end
              field_width = [field_width, new_len[x]].max

              # Now we need to justify the strings.
              new_pos[x] = Slithernix::Cdk.justify_string(
                field_width + 1,
                new_len[x],
                new_pos[x],
              )
            end

            if status
              destroy_info

              # Copy in the new information
              @list_size = count
              @item = new_items
              @item_pos = new_pos
              @item_len = new_len
            end
          else
            destroy_info
            status = true
          end

          status
        end

        # Go through the list and determine the widest item.
        def maximum_field_width
          max_width = -2**30

          (0...@list_size).each do |x|
            max_width = [max_width, @item_len[x]].max
          end
          [max_width, 0].max
        end

        def update_field_width
          want = maximum_field_width + 1
          have = @box_width - @label_len - (2 * @border_size)
          @field_width = [want, have].min
        end

        # Make the field window.
        def create_field_win(ypos, xpos)
          @field_win = @win.subwin(1, @field_width, ypos, xpos)
          unless @field_win.nil?
            @field_win.keypad(true)
            @input_window = @field_win
            return true
          end
          false
        end

        def position
          super(@win)
        end
      end
    end
  end
end
