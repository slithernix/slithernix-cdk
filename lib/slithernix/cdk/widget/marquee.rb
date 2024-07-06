# frozen_string_literal: true

require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class Marquee < Slithernix::Cdk::Widget
        def initialize(cdkscreen, xpos, ypos, width, box, shadow)
          super()

          @screen = cdkscreen
          @parent = cdkscreen.window
          @win = Curses::Window.new(1, 1, ypos, xpos)
          @active = true
          @width = width
          @shadow = shadow

          setBox(box)
          if @win.nil?
            destroy
            # return (0);
          end

          cdkscreen.register(:Marquee, self)
        end

        # This activates the widget.
        def activate(mesg, delay, repeat, box)
          mesg_length = []
          start_pos = 0
          first_char = 0
          last_char = 1
          repeat_count = 0
          view_size = 0
          message = []
          first_time = true

          return -1 if mesg.nil? || (mesg == '')

          # Keep the box info, setting BorderOf()
          setBox(box)

          padding = mesg[-1] == ' ' ? 0 : 1

          # Translate the string to a chtype array
          message = Slithernix::Cdk.char2Chtype(mesg, mesg_length, [])

          # Draw in the widget.
          draw(@box)
          view_limit = @width - (2 * @border_size)

          # Start doing the marquee thing...
          oldcurs = Curses.curs_set(0)
          while @active
            if first_time
              first_char = 0
              last_char = 1
              view_size = last_char - first_char
              start_pos = @width - view_size - @border_size

              first_time = false
            end

            # Draw in the characters.
            y = first_char
            (start_pos...(start_pos + view_size)).each do |x|
              ch = y < mesg_length[0] ? message[y].ord : ' '.ord
              @win.mvwaddch(@border_size, x, ch)
              y += 1
            end
            @win.refresh

            # Set my variables
            if mesg_length[0] < view_limit
              if last_char < (mesg_length[0] + padding)
                last_char += 1
                view_size += 1
                start_pos = @width - view_size - @border_size
              elsif start_pos > @border_size
                # This means the whole string is visible.
                start_pos -= 1
                view_size = mesg_length[0] + padding
              else
                # We have to start chopping the view_size
                start_pos = @border_size
                first_char += 1
                view_size -= 1
              end
            elsif start_pos > @border_size
              last_char += 1
              view_size += 1
              start_pos -= 1
            elsif last_char < mesg_length[0] + padding
              first_char += 1
              last_char += 1
              start_pos = @border_size
              view_size = view_limit
            else
              start_pos = @border_size
              first_char += 1
              view_size -= 1
            end

            # OK, let's check if we have to start over.
            if view_size <= 0 && first_char == (mesg_length[0] + padding)
              # Check if we repeat a specified number or loop indefinitely
              repeat_count += 1
              break if repeat.positive? && repeat_count >= repeat

              # Time to start over.
              @win.mvwaddch(@border_size, @border_size, ' '.ord)
              @win.refresh
              first_time = true
            end

            # Now sleep
            Curses.napms(delay * 10)
          end
          oldcurs = 1 if oldcurs.negative?
          Curses.curs_set(oldcurs)
          0
        end

        # This de-activates a marquee widget.
        def deactivate
          @active = false
        end

        # This moves the marquee field to the given location.
        # Inherited
        # def move(xplace, yplace, relative, refresh_flag)
        # end

        # This draws the marquee widget on the screen.
        def draw(box)
          # Keep the box information.
          @box = box

          # Do we need to draw a shadow???
          Slithernix::Cdk::Draw.drawShadow(@shadow_win) unless @shadow_win.nil?

          # Box it if needed.
          Slithernix::Cdk::Draw.drawObjBox(@win, self) if box

          # Refresh the window.
          @win.refresh
        end

        # This destroys the widget.
        def destroy
          # Clean up the windows.
          Slithernix::Cdk.deleteCursesWindow(@shadow_win)
          Slithernix::Cdk.deleteCursesWindow(@win)

          # Clean the key bindings.
          cleanBindings(:Marquee)

          # Unregister this widget.
          Slithernix::Cdk::Screen.unregister(:Marquee, self)
        end

        # This erases the widget.
        def erase
          return unless validCDKObject

          Slithernix::Cdk.eraseCursesWindow(@win)
          Slithernix::Cdk.eraseCursesWindow(@shadow_win)
        end

        # This sets the widget box attribute.
        def setBox(box)
          xpos = @win.nil? ? 0 : @win.begx
          ypos = @win.nil? ? 0 : @win.begy

          super

          layoutWidget(xpos, ypos)
        end

        def position
          super(@win)
        end

        # This sets the background attribute of the widget.
        def setBKattr(attrib)
          Curses.wbkgd(@win, attrib)
        end

        def layoutWidget(xpos, ypos)
          parent_width = @screen.window.maxx

          Slithernix::Cdk::Widget::Marquee.discardWin(@win)
          Slithernix::Cdk::Widget::Marquee.discardWin(@shadow_win)

          box_width = Slithernix::Cdk.setWidgetDimension(
            parent_width,
            @width,
            0,
          )

          box_height = (@border_size * 2) + 1

          # Rejustify the x and y positions if we need to.
          xtmp = [xpos]
          ytmp = [ypos]

          Slithernix::Cdk.alignxy(
            @screen.window,
            xtmp,
            ytmp,
            box_width,
            box_height,
          )

          window = Curses::Window.new(box_height, box_width, ytmp[0], xtmp[0])

          return if window.nil?

          @win = window
          @box_height = box_height
          @box_width = box_width

          @win.keypad(true)

          # Do we want a shadow?
          return unless @shadow

          @shadow_win = @screen.window.subwin(box_height, box_width,
                                              ytmp[0] + 1, xtmp[0] + 1)
        end

        def self.discardWin(winp)
          return if winp.nil?

          winp.erase
          winp.refresh
          winp.close
        end
      end
    end
  end
end
