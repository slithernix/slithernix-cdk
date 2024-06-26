module Cdk
  module Draw
    # This sets up a basic set of color pairs. These can be redefined if wanted
    def Draw.initCDKColor
      color = [Curses::COLOR_WHITE, Curses::COLOR_RED, Curses::COLOR_GREEN,
          Curses::COLOR_YELLOW, Curses::COLOR_BLUE, Curses::COLOR_MAGENTA,
          Curses::COLOR_CYAN, Curses::COLOR_BLACK]
      pair = 1

      if Curses.has_colors?
        # XXX: Only checks if terminal has colours not if colours are started
        Curses.start_color
        limit = Curses.colors < 8 ? Curses.colors : 8

        # Create the color pairs
        (0...limit).each do |fg|
          (0...limit).each do |bg|
            Curses.init_pair(pair, color[fg], color[bg])
            pair += 1
          end
        end
      end
    end

    # This prints out a box around a window with attributes
    def Draw.boxWindow(window, attr)
      tlx = 0
      tly = 0
      brx = window.maxx - 1
      bry = window.maxy - 1

      # Draw horizontal lines.
      window.mvwhline(tly, 0, Cdk::ACS_HLINE | attr, window.maxx)
      window.mvwhline(bry, 0, Cdk::ACS_HLINE | attr, window.maxx)

      # Draw horizontal lines.
      window.mvwvline(0, tlx, Cdk::ACS_VLINE | attr, window.maxy)
      window.mvwvline(0, brx, Cdk::ACS_VLINE | attr, window.maxy)

      # Draw in the corners.
      window.mvwaddch(tly, tlx, Cdk::ACS_ULCORNER | attr)
      window.mvwaddch(tly, brx, Cdk::ACS_URCORNER | attr)
      window.mvwaddch(bry, tlx, Cdk::ACS_LLCORNER | attr)
      window.mvwaddch(bry, brx, Cdk::ACS_LRCORNER | attr)
      window.refresh
    end

    # This draws a box with attributes and lets the user define each
    # element of the box
    def Draw.attrbox(win, tlc, trc, blc, brc, horz, vert, attr)
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

    # Draw a box around the given window using the object's defined
    # line-drawing characters
    def Draw.drawObjBox(win, object)
      Draw.attrbox(win,
          object.ULChar, object.URChar, object.LLChar, object.LRChar,
          object.HZChar, object.VTChar, object.BXAttr)
    end

    # This draws a line on the given window. (odd angle lines not working yet)
    def Draw.drawLine(window, startx, starty, endx, endy, line)
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
        xratio = if height > width then 1 else width / height end
        yration = if width > height then width / height else 1 end
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
            x = if xdiff < 0 then x - 1 else x + 1 end
            xadj += 1
          else
            xadj = 0
          end
          if yadj != yratio
            y = if ydiff < 0 then y - 1 else y + 1 end
            yadj += 1
          else
            yadj = 0
          end
        end
      end
    end

    # This draws a shadow around a window.
    def Draw.drawShadow(shadow_win)
      unless shadow_win.nil?
        x_hi = shadow_win.maxx - 1
        y_hi = shadow_win.maxy - 1

        # Draw the line on the bottom.
        shadow_win.mvwhline(y_hi, 1, Cdk::ACS_HLINE | Curses::A_DIM, x_hi)

        # Draw the line on the right.
        shadow_win.mvwvline(0, x_hi, Cdk::ACS_VLINE | Curses::A_DIM, y_hi)

        shadow_win.mvwaddch(0, x_hi, Cdk::ACS_URCORNER | Curses::A_DIM)
        shadow_win.mvwaddch(y_hi, 0, Cdk::ACS_LLCORNER | Curses::A_DIM)
        shadow_win.mvwaddch(y_hi, x_hi, Cdk::ACS_LRCORNER | Curses::A_DIM)
        shadow_win.refresh
      end
    end

    # Write a string of blanks using writeChar()
    def Draw.writeBlanks(window, xpos, ypos, align, start, endn)
      if start < endn
        want = (endn - start) + 1000
        blanks = ''

        Cdk.cleanChar(blanks, want - 1, ' ')
        Draw.writeChar(window, xpos, ypos, blanks, align, start, endn)
      end
    end

    # This writes out a char string with no attributes
    def Draw.writeChar(window, xpos, ypos, string, align, start, endn)
      Draw.writeCharAttrib(window, xpos, ypos, string, Curses::A_NORMAL,
          align, start, endn)
    end

    # This writes out a char string with attributes
    def Draw.writeCharAttrib(window, xpos, ypos, string, attr, align,
        start, endn)
      display = endn - start

      if align == Cdk::HORIZONTAL
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
    def Draw.writeChtype (window, xpos, ypos, string, align, start, endn)
      Draw.writeChtypeAttrib(window, xpos, ypos, string, Curses::A_NORMAL,
          align, start, endn)
    end

    # This writes out a chtype string with the given attributes added.
    def Draw.writeChtypeAttrib(window, xpos, ypos, string, attr,
        align, start, endn)
      diff = endn - start
      display = 0
      x = 0
      if align == Cdk::HORIZONTAL
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
