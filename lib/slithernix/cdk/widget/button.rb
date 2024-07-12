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

        # This allows the user to use the cursor keys to adjust the
        # position of the widget.
        def position
          # Declare some variables
          orig_x = @win.begx
          orig_y = @win.begy
          key = 0

          # Let them move the widget around until they hit return
          # SUSPECT FOR BUG
          while key != Curses::KEY_ENTER && key != Slithernix::Cdk::KEY_RETURN
            key = getch([])
            if [Curses::KEY_UP, '8'].include?(key)
              if @win.begy.positive?
                move(0, -1, true, true)
              else
                Slithernix::Cdk.beep
              end
            elsif [Curses::KEY_DOWN, '2'].include?(key)
              if @win.begy + @win.maxy < @screen.window.maxy - 1
                move(0, 1, true, true)
              else
                Slithernix::Cdk.beep
              end
            elsif [Curses::KEY_LEFT, '4'].include?(key)
              if @win.begx.positive?
                move(-1, 0, true, true)
              else
                Slithernix::Cdk.beep
              end
            elsif [Curses::KEY_RIGHT, '6'].include?(key)
              if @win.begx + @win.maxx < @screen.window.maxx - 1
                move(1, 0, true, true)
              else
                Slithernix::Cdk.beep
              end
            elsif key == '7'
              if @win.begy.positive? && @win.begx.positive?
                move(-1, -1, true, true)
              else
                Slithernix::Cdk.beep
              end
            elsif key == '9'
              if @win.begx + @win.maxx < @screen.window.maxx - 1 &&
                 @win.begy.positive?
                move(1, -1, true, true)
              else
                Slithernix::Cdk.beep
              end
            elsif key == '1'
              if @win.begx.positive? &&
                 @win.begx + @win.maxx < @screen.window.maxx - 1
                move(-1, 1, true, true)
              else
                Slithernix::Cdk.beep
              end
            elsif key == '3'
              if @win.begx + @win.maxx < @screen.window.maxx - 1 &&
                 @win.begy + @win.maxy < @screen.window.maxy - 1
                move(1, 1, true, true)
              else
                Slithernix::Cdk.beep
              end
            elsif key == '5'
              move(Slithernix::Cdk::CENTER, Slithernix::Cdk::CENTER, false,
                   true)
            elsif key == 't'
              move(@win.begx, Slithernix::Cdk::TOP, false, true)
            elsif key == 'b'
              move(@win.begx, Slithernix::Cdk::BOTTOM, false, true)
            elsif key == 'l'
              move(Slithernix::Cdk::LEFT, @win.begy, false, true)
            elsif key == 'r'
              move(Slithernix::Cdk::RIGHT, @win.begy, false, true)
            elsif key == 'c'
              move(Slithernix::Cdk::CENTER, @win.begy, false, true)
            elsif key == 'C'
              move(@win.begx, Slithernix::Cdk::CENTER, false, true)
            elsif key == Slithernix::Cdk::REFRESH
              @screen.erase
              @screen.refresh
            elsif key == Slithernix::Cdk::KEY_ESC
              move(orig_x, orig_y, false, true)
            elsif key != Slithernix::Cdk::KEY_RETURN && key != Curses::KEY_ENTER
              Slithernix::Cdk.beep
            end
          end
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
