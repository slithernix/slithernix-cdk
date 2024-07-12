# frozen_string_literal: true

module Slithernix
  module Cdk
    module Draw
      def self.init_color
        return nil unless Curses.has_colors?

        Curses.start_color
        limit = [Curses.colors, 256].min
        limit = Math.sqrt(limit)

        color_values = 0...limit
        color_pairs = {}

        pair = 1
        color_values.each do |fg|
          color_values.each do |bg|
            Curses.init_pair(pair, fg, bg)
            color_pairs[pair] = [fg, bg]
            pair += 1
          end
        end

        color_pairs
      end

      # This prints out a box around a window with attributes
      def self.box_window(window, attr)
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
        win.refresh if count != 0
      end

      # Draw a box around the given window using the widget's defined
      # line-drawing characters
      def self.draw_obj_box(win, widget)
        attrbox(
          win,
          widget.upper_left_corner_char,
          widget.upper_right_corner_char,
          widget.lower_left_corner_character,
          widget.lower_right_corner_character,
          widget.horizontal_line_char,
          widget.vertical_line_char,
          widget.box_attr
        )
      end

      # This draws a line on the given window. (odd angle lines not working yet)
      def self.draw_line(window, startx, starty, endx, endy, line)
        xdiff = endx - startx
        ydiff = endy - starty
        x = 0
        y = 0

        # Determine if we're drawing a horizontal or vertical line.
        if ydiff.zero?
          window.mvwhline(starty, startx, line, xdiff) if xdiff.positive?
        elsif xdiff.zero?
          window.mvwvline(starty, startx, line, ydiff) if ydiff.positive?
        else
          # We need to determine the angle of the line.
          height = xdiff
          width = ydiff
          xratio = height > width ? 1 : width / height
          width > height ? width / height : 1
          xadj = 0
          yadj = 0

          # Set the vars
          x = startx
          y = starty
          while x != endx && y != endy
            # Add the char to the window
            window.mvwaddch(y, x, line)

            # Make the x and y adjustments.
            if xadj == xratio
              xadj = 0
            else
              x = xdiff.negative? ? x - 1 : x + 1
              xadj += 1
            end
            if yadj == yratio
              yadj = 0
            else
              y = ydiff.negative? ? y - 1 : y + 1
              yadj += 1
            end
          end
        end
      end

      # This draws a shadow around a window.
      def self.draw_shadow(shadow_win)
        return if shadow_win.nil?

        x_hi = shadow_win.maxx - 1
        y_hi = shadow_win.maxy - 1

        # Draw the line on the bottom.
        shadow_win.mvwhline(
          y_hi,
          1,
          Slithernix::Cdk::ACS_HLINE | Curses::A_DIM,
          x_hi,
        )

        # Draw the line on the right.
        shadow_win.mvwvline(
          0,
          x_hi,
          Slithernix::Cdk::ACS_VLINE | Curses::A_DIM,
          y_hi,
        )

        shadow_win.mvwaddch(
          0,
          x_hi,
          Slithernix::Cdk::ACS_URCORNER | Curses::A_DIM,
        )

        shadow_win.mvwaddch(
          y_hi,
          0,
          Slithernix::Cdk::ACS_LLCORNER | Curses::A_DIM,
        )

        shadow_win.mvwaddch(
          y_hi,
          x_hi,
          Slithernix::Cdk::ACS_LRCORNER | Curses::A_DIM,
        )

        shadow_win.refresh
      end

      # Write a string of blanks using write_char()
      def self.write_blanks(window, xpos, ypos, align, start, endn)
        return unless start < endn

        want = (endn - start) + 1000
        blanks = String.new

        Slithernix::Cdk.clean_char(blanks, want - 1, ' ')
        write_char(window, xpos, ypos, blanks, align, start, endn)
      end

      # This writes out a char string with no attributes
      def self.write_char(window, xpos, ypos, string, align, start, endn)
        write_char_attrib(
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
      def self.write_char_attrib(window, xpos, ypos, string, attr, align, start, endn)
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
      def self.write_chtype(window, xpos, ypos, string, align, start, endn)
        write_chtype_attrib(
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
      def self.write_chtype_attrib(window, xpos, ypos, string, attr, align, start, endn)
        diff = endn - start
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
