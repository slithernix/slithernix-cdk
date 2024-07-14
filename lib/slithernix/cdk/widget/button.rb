# frozen_string_literal: true

module Slithernix
  module Cdk
    class Widget
      class Button < Slithernix::Cdk::Widget
        def initialize(cdkscreen, xplace, yplace, text, callback, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          box_width = 0
          xpos = xplace
          ypos = yplace

          set_box(box)
          box_height = 1 + (2 * @border_size)

          # Translate the string to a chtype array.
          info_len = []
          info_pos = []
          @info = Slithernix::Cdk.char_to_chtype(text, info_len, info_pos)
          @info_len = info_len[0]
          @info_pos = info_pos[0]
          box_width = [box_width, @info_len].max + (2 * @border_size)

          # Create the string alignments.
          @info_pos = Slithernix::Cdk.justify_string(
            box_width - (2 * @border_size),
            @info_len,
            @info_pos,
          )

          # Make sure we didn't extend beyond the dimensions of the window.
          box_width = parent_width if box_width > parent_width
          box_height = parent_height if box_height > parent_height

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

          # Create the button.
          @screen = cdkscreen
          # ObjOf (button)->fn = &my_funcs;
          @parent = cdkscreen.window
          @win = Curses::Window.new(box_height, box_width, ypos, xpos)
          @shadow_win = nil
          @xpos = xpos
          @ypos = ypos
          @box_width = box_width
          @box_height = box_height
          @callback = callback
          @input_window = @win
          @accepts_focus = true
          @shadow = shadow

          if @win.nil?
            destroy
            return nil
          end

          @win.keypad(true)

          # If a shadow was requested, then create the shadow window.
          if shadow
            @shadow_win = Curses::Window.new(
              box_height,
              box_width,
              ypos + 1,
              xpos + 1,
            )
          end

          # Register this baby.
          cdkscreen.register(:Button, self)
        end

        # This was added for the builder.
        def activate(actions)
          draw(@box)
          ret = -1

          if actions.nil? || actions.empty?
            loop do
              input = getch([])

              # Inject the character into the widget.
              ret = inject(input)
              return ret if @exit_type != :EARLY_EXIT
            end
          else
            # Inject each character one at a time.
            actions.each do |_x|
              ret = inject(action)
              return ret if @exit_type == :EARLY_EXIT
            end
          end

          # Set the exit type and exit
          set_exit_type(0)
          -1
        end

        # This sets multiple attributes of the widget.
        def set(mesg, box)
          set_message(mesg)
          set_box(box)
        end

        # This sets the information within the button.
        def set_message(info)
          info_len = []
          info_pos = []
          @info = Slithernix::Cdk.char_to_chtype(info, info_len, info_pos)
          @info_len = info_len[0]
          @info_pos = Slithernix::Cdk.justify_string(
            @box_width - (2 * @border_size),
            info_pos[0],
          )

          # Redraw the button widget.
          erase
          draw(box)
        end

        def get_message
          @info
        end

        # This sets the background attribute of the widget.
        def set_background_attr(attrib)
          @win.wbkgd(attrib)
        end

        def draw_text
          box_width = @box_width

          # Draw in the message.
          (0...(box_width - (2 * @border_size))).each do |i|
            pos = @info_pos
            len = @info_len
            c = if i >= pos && (i - pos) < len
                  @info[i - pos]
                else
                  ' '
                end

            c = Curses::A_REVERSE | c if @has_focus

            @win.mvwaddch(@border_size, i + @border_size, c)
          end
        end

        # This draws the button widget
        def draw(_box)
          # Is there a shadow?
          unless @shadow_win.nil?
            Slithernix::Cdk::Draw.draw_shadow(@shadow_win)
          end

          # Box the widget if asked.
          Slithernix::Cdk::Draw.draw_obj_box(@win, self) if @box
          draw_text
          @win.refresh
        end

        # This erases the button widget.
        def erase
          return unless is_valid_widget?

          Slithernix::Cdk.erase_curses_window(@win)
          Slithernix::Cdk.erase_curses_window(@shadow_win)
        end

        # This moves the button field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          current_x = @win.begx
          current_y = @win.begy
          xpos = xplace
          ypos = yplace

          # If this is a relative move, then we will adjust where we want
          # to move to.
          if relative
            xpos = @win.begx + xplace
            ypos = @win.begy + yplace
          end

          # Adjust the window if we need to.
          xtmp = [xpos]
          ytmp = [ypos]
          Slithernix::Cdk.alignxy(
            @screen.window,
            xtmp,
            ytmp,
            @box_width,
            @box_height,
          )
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Get the difference
          xdiff = current_x - xpos
          ydiff = current_y - ypos

          # Move the window to the new location.
          Slithernix::Cdk.move_curses_window(@win, -xdiff, -ydiff)
          Slithernix::Cdk.move_curses_window(@shadow_win, -xdiff, -ydiff)

          # Thouch the windows so they 'move'.
          Slithernix::Cdk::Screen.refresh_window(@screen.window)

          # Redraw the window, if they asked for it.
          draw(@box) if refresh_flag
        end

        def position
          orig_x, orig_y = @win.begx, @win.begy
          key = 0

          until [Curses::KEY_ENTER, Slithernix::Cdk::KEY_RETURN].include?(key)
            key = getch([])
            handle_key(key, orig_x, orig_y)
          end
        end


        def handle_key(key, orig_x, orig_y)
          case key
          when Curses::KEY_UP, '8' then move_if_possible(0, -1)
          when Curses::KEY_DOWN, '2' then move_if_possible(0, 1)
          when Curses::KEY_LEFT, '4' then move_if_possible(-1, 0)
          when Curses::KEY_RIGHT, '6' then move_if_possible(1, 0)
          when '7' then move_if_possible(-1, -1)
          when '9' then move_if_possible(1, -1)
          when '1' then move_if_possible(-1, 1)
          when '3' then move_if_possible(1, 1)
          when '5'
            move(
              Slithernix::Cdk::CENTER,
              Slithernix::Cdk::CENTER,
              false,
              true
            )
          when 't' then move(@win.begx, Slithernix::Cdk::TOP, false, true)
          when 'b' then move(@win.begx, Slithernix::Cdk::BOTTOM, false, true)
          when 'l' then move(Slithernix::Cdk::LEFT, @win.begy, false, true)
          when 'r' then move(Slithernix::Cdk::RIGHT, @win.begy, false, true)
          when 'c' then move(Slithernix::Cdk::CENTER, @win.begy, false, true)
          when 'C' then move(@win.begx, Slithernix::Cdk::CENTER, false, true)
          when Slithernix::Cdk::REFRESH
            @screen.erase
            @screen.refresh
          when Slithernix::Cdk::KEY_ESC
            move(orig_x, orig_y, false, true)
          else
            unless [
              Slithernix::Cdk::KEY_RETURN,
              Curses::KEY_ENTER
            ].include?(key)
              Slithernix::Cdk.beep
            end
          end
        end

        def move_if_possible(dx, dy)
          new_x, new_y = @win.begx + dx, @win.begy + dy
          if position_valid?(new_x, new_y)
            move(dx, dy, true, true)
          else
            Slithernix::Cdk.beep
          end
        end

        def position_valid?(x, y)
          x >= 0 && y >= 0 &&
            x + @win.maxx < @screen.window.maxx &&
            y + @win.maxy < @screen.window.maxy
        end

        # This destroys the button widget pointer.
        def destroy
          Slithernix::Cdk.delete_curses_window(@shadow_win)
          Slithernix::Cdk.delete_curses_window(@win)

          clean_bindings(:Button)

          Slithernix::Cdk::Screen.unregister(:Button, self)
        end

        # This injects a single character into the widget.
        def inject(input)
          ret = -1
          complete = false

          set_exit_type(0)

          # Check a predefined binding.
          if check_bind(:Button, input)
            complete = true
          else
            case input
            when Slithernix::Cdk::KEY_ESC
              set_exit_type(input)
              complete = true
            when Curses::Error
              set_exit_type(input)
              complete = true
            when ' ', Slithernix::Cdk::KEY_RETURN, Curses::KEY_ENTER
              @callback&.call(self)
              set_exit_type(Curses::KEY_ENTER)
              ret = 0
              complete = true
            when Slithernix::Cdk::REFRESH
              @screen.erase
              @screen.refresh
            else
              Slithernix::Cdk.beep
            end
          end

          set_exit_type(0) unless complete

          @result_data = ret
          ret
        end

        def focus
          draw_text
          @win.refresh
        end

        def unfocus
          draw_text
          @win.refresh
        end
      end
    end
  end
end
