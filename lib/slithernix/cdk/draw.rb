module Slithernix
  module Cdk
    module Draw
      # Set up all basic BG/FG color pairs based on what Curses supports
      def self.initCDKColor
        if Curses.has_colors?
          Curses.start_color
          limit = [Curses.colors, 256].min

          # Create color pairs for all combinations of foreground and background colors
          pair = 1
          (0...limit).each do |fg|
            (0...limit).each do |bg|
              Curses.init_pair(pair, fg, bg)
              pair += 1
            end
          end
        end
      end

      # This prints out a box around a window with attributes
      def self.boxWindow(window, attr)
        tlx = 0
        tly = 0
        brx = window.maxx - 1
        bry = window.maxy - 1

        # Draw horizontal lines.
        window.mvwhline(tly, 0, Slithernix::Cdk::ACS_HLINE | attr, window.maxx)
        window.mvwhline(bry, 0, Slithernix::Cdk::ACS_HLINE | attr, window.maxx)

        # Draw horizontal lines.
        window.mvwvline(0, tlx, Slithernix::Cdk::ACS_VLINE | attr, window.maxy)
        window.mvwvline(0, brx, Slithernix::Cdk::ACS_VLINE | attr, window.maxy)

        # Draw in the corners.
        window.mvwaddch(tly, tlx, Slithernix::Cdk::ACS_ULCORNER | attr)
        window.mvwaddch(tly, brx, Slithernix::Cdk::ACS_URCORNER | attr)
        window.mvwaddch(bry, tlx, Slithernix::Cdk::ACS_LLCORNER | attr)
        window.mvwaddch(bry, brx, Slithernix::Cdk::ACS_LRCORNER | attr)
        window.refresh
      end

      # This draws a box with attributes and lets the user define each
      # element of the box
      def self.attrbox(win, tlc, trc, blc, brc, horz, vert, attr)
        x1 = 0
        y1 = 0
        y2 = win.maxy - 1
        x2 = win.maxx - 1
        count = 0

        # Draw horizontal lines
        if horz != 0
          win.mvwhline(y1, 0, horz | attr, win.maxx)
          win.mvwhline(y2, 0, horz | attr, win.maxx)
          count += 1
        end

        # Draw vertical lines
        if vert != 0
          win.mvwvline(0, x1, vert | attr, win.maxy)
          win.mvwvline(0, x2, vert | attr, win.maxy)
          count += 1
        end

        # Draw in the corners.
        if tlc != 0
          win.mvwaddch(y1, x1, tlc | attr)
          count += 1
        end
        if trc != 0
          win.mvwaddch(y1, x2, trc | attr)
          count += 1
        end
        if blc != 0
          win.mvwaddch(y2, x1, blc | attr)
          count += 1
        end
        if brc != 0
          win.mvwaddch(y2, x2, brc | attr)
          count += 1
        end
        if count != 0
          win.refresh
        end
      end

      # Draw a box around the given window using the widget's defined
      # line-drawing characters
      def self.drawObjBox(win, widget)
        self.attrbox(
          win,
          widget.ULChar,
          widget.URChar,
          widget.LLChar,
          widget.LRChar,
          widget.HZChar,
          widget.VTChar,
          widget.BXAttr
        )
      end

      # This draws a line on the given window. (odd angle lines not working yet)
      def self.drawLine(window, startx, starty, endx, endy, line)
        xdiff = endx - startx
        ydiff = endy - starty
        x = 0
        y = 0

        # Determine if we're drawing a horizontal or vertical line.
        if ydiff == 0
          if xdiff > 0
            window.mvwhline(starty, startx, line, xdiff)
          end
        elsif xdiff == 0
          if ydiff > 0
            window.mvwvline(starty, startx, line, ydiff)
          end
        else
          # We need to determine the angle of the line.
          height = xdiff
          width = ydiff
          xratio = height > width ? 1 : width / height
          yration = width > height ? width / height : 1
          xadj = 0
          yadj = 0

          # Set the vars
          x = startx
          y = starty
          while x!= endx && y != endy
            # Add the char to the window
            window.mvwaddch(y, x, line)

            # Make the x and y adjustments.
            if xadj != xratio
              x = xdiff < 0 ? x - 1 : x + 1
              xadj += 1
            else
              xadj = 0
            end
            if yadj != yratio
              y = ydiff < 0 ? y - 1 : y + 1
              yadj += 1
            else
              yadj = 0
            end
          end
        end
      end

      # This draws a shadow around a window.
      def self.drawShadow(shadow_win)
        unless shadow_win.nil?
          x_hi = shadow_win.maxx - 1
          y_hi = shadow_win.maxy - 1

          # Draw the line on the bottom.
          shadow_win.mvwhline(y_hi, 1, Slithernix::Cdk::ACS_HLINE | Curses::A_DIM, x_hi)

          # Draw the line on the right.
          shadow_win.mvwvline(0, x_hi, Slithernix::Cdk::ACS_VLINE | Curses::A_DIM, y_hi)

          shadow_win.mvwaddch(0, x_hi, Slithernix::Cdk::ACS_URCORNER | Curses::A_DIM)
          shadow_win.mvwaddch(y_hi, 0, Slithernix::Cdk::ACS_LLCORNER | Curses::A_DIM)
          shadow_win.mvwaddch(y_hi, x_hi, Slithernix::Cdk::ACS_LRCORNER | Curses::A_DIM)
          shadow_win.refresh
        end
      end

      # Write a string of blanks using writeChar()
      def self.writeBlanks(window, xpos, ypos, align, start, endn)
        if start < endn
          want = (endn - start) + 1000
          blanks = ''

          Slithernix::Cdk.cleanChar(blanks, want - 1, ' ')
          self.writeChar(window, xpos, ypos, blanks, align, start, endn)
        end
      end

      # This writes out a char string with no attributes
      def self.writeChar(window, xpos, ypos, string, align, start, endn)
        self.writeCharAttrib(
          window,
          xpos,
          ypos,
          string,
          Curses::A_NORMAL,
          align,
          start,
          endn
        )
      end

      # This writes out a char string with attributes
      def self.writeCharAttrib(window, xpos, ypos, string, attr, align,
          start, endn)
        display = endn - start

        if align == Slithernix::Cdk::HORIZONTAL
          # Draw the message on a horizontal axis
          display = [display, window.maxx - 1].min
          (0...display).each do |x|
            window.mvwaddch(ypos, xpos + x, string[x + start].ord | attr)
          end
        else
          # Draw the message on a vertical axis
          display = [display, window.maxy - 1].min
          (0...display).each do |x|
            window.mvwaddch(ypos + x, xpos, string[x + start].ord | attr)
          end
        end
      end

      # This writes out a chtype string
      def self.writeChtype(window, xpos, ypos, string, align, start, endn)
        self.writeChtypeAttrib(
          window,
          xpos,
          ypos,
          string,
          Curses::A_NORMAL,
          align,
          start,
          endn
        )
      end

      # This writes out a chtype string with the given attributes added.
      def self.writeChtypeAttrib(window, xpos, ypos, string, attr,align, start, endn)
        diff = endn - start
        display = 0
        x = 0
        if align == Slithernix::Cdk::HORIZONTAL
          # Draw the message on a horizontal axis.
          display = [diff, window.maxx - xpos].min
          (0...display).each do |x|
            window.mvwaddch(ypos, xpos + x, string[x + start].ord | attr)
          end
        else
          # Draw the message on a vertical axis.
          display = [diff, window.maxy - ypos].min
          (0...display).each do |x|
            window.mvwaddch(ypos + x, xpos, string[x + start].ord | attr)
          end
        end
      end
    end
  end
end
