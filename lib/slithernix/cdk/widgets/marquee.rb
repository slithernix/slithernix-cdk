require_relative '../objects'

module Cdk
  class MARQUEE < Cdk::Objects
    def initialize(cdkscreen, xpos, ypos, width, box, shadow)
      super()

      @screen = cdkscreen
      @parent = cdkscreen.window
      @win = Curses::Window.new(1, 1, ypos, xpos)
      @active = true
      @width = width
      @shadow = shadow

      self.setBox(box)
      if @win.nil?
        self.destroy
        # return (0);
      end

      cdkscreen.register(:MARQUEE, self)
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

      if mesg.nil? or mesg == ''
        return -1
      end

      # Keep the box info, setting BorderOf()
      self.setBox(box)

      padding = if mesg[-1] == ' ' then 0 else 1 end

      # Translate the string to a chtype array
      message = Cdk.char2Chtype(mesg, mesg_length, [])

      # Draw in the widget.
      self.draw(@box)
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
          ch = if y < mesg_length[0] then message[y].ord else ' '.ord end
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
        else
          if start_pos > @border_size
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
        end

        # OK, let's check if we have to start over.
        if view_size <= 0 && first_char == (mesg_length[0] + padding)
          # Check if we repeat a specified number or loop indefinitely
          repeat_count += 1
          if repeat > 0 && repeat_count >= repeat
            break
          end

          # Time to start over.
          @win.mvwaddch(@border_size, @border_size, ' '.ord)
          @win.refresh
          first_time = true
        end

        # Now sleep
        Curses.napms(delay * 10)
      end
      if oldcurs < 0
        oldcurs = 1
      end
      Curses.curs_set(oldcurs)
      return 0
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
      unless @shadow_win.nil?
        Draw.drawShadow(@shadow_win)
      end

      # Box it if needed.
      if box
        Draw.drawObjBox(@win, self)
      end

      # Refresh the window.
      @win.refresh
    end

    # This destroys the widget.
    def destroy
      # Clean up the windows.
      Cdk.deleteCursesWindow(@shadow_win)
      Cdk.deleteCursesWindow(@win)

      # Clean the key bindings.
      self.cleanBindings(:MARQUEE)

      # Unregister this object.
      Cdk::Screen.unregister(:MARQUEE, self)
    end

    # This erases the widget.
    def erase
      if self.validCDKObject
        Cdk.eraseCursesWindow(@win)
        Cdk.eraseCursesWindow(@shadow_win)
      end
    end

    # This sets the widgets box attribute.
    def setBox(box)
      xpos = if @win.nil? then 0 else @win.begx end
      ypos = if @win.nil? then 0 else @win.begy end

      super

      self.layoutWidget(xpos, ypos)
    end

    def object_type
      :MARQUEE
    end

    def position
      super(@win)
    end

    # This sets the background attribute of the widget.
    def setBKattr(attrib)
      Curses.wbkgd(@win, attrib)
    end

    def layoutWidget(xpos, ypos)
      cdkscreen = @screen
      parent_width = @screen.window.maxx

      Cdk::MARQUEE.discardWin(@win)
      Cdk::MARQUEE.discardWin(@shadow_win)

      box_width = Cdk.setWidgetDimension(parent_width, @width, 0)
      box_height = (@border_size * 2) + 1

      # Rejustify the x and y positions if we need to.
      xtmp = [xpos]
      ytmp = [ypos]
      Cdk.alignxy(@screen.window, xtmp, ytmp, box_width, box_height)
      window = Curses::Window.new(box_height, box_width, ytmp[0], xtmp[0])

      unless window.nil?
        @win = window
        @box_height = box_height
        @box_width = box_width

        @win.keypad(true)

        # Do we want a shadow?
        if @shadow
          @shadow_win = @screen.window.subwin(box_height, box_width,
              ytmp[0] + 1, xtmp[0] + 1)
        end
      end
    end

    def self.discardWin(winp)
      unless winp.nil?
        winp.erase
        winp.refresh
        winp.close
      end
    end
  end
end
