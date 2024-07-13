# frozen_string_literal: true

module Slithernix
  module Cdk
    class Widget
      class Graph < Slithernix::Cdk::Widget
        def initialize(cdkscreen, xplace, yplace, height, width, title, xtitle, ytitle)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy

          set_box(false)

          box_height = Slithernix::Cdk.set_widget_dimension(
            parent_height,
            height,
            3,
          )
          box_width = Slithernix::Cdk.set_widget_dimension(
            parent_width,
            width,
            0
          )
          box_width = set_title(title, box_width)
          box_height += @title_lines
          box_width = [parent_width, box_width].min
          box_height = [parent_height, box_height].min

          # Rejustify the x and y positions if we need to
          xtmp = [xplace]
          ytmp = [yplace]
          Slithernix::Cdk.alignxy(
            cdkscreen.window,
            xtmp,
            ytmp,
            box_width,
            box_height
          )
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Create the widget pointer
          @screen = cdkscreen
          @parent = cdkscreen.window
          @win = Curses::Window.new(box_height, box_width, ypos, xpos)
          @box_height = box_height
          @box_width = box_width
          @minx = 0
          @maxx = 0
          @xscale = 0
          @yscale = 0
          @count = 0
          @display_type = :LINE

          if @win.nil?
            destroy
            return nil
          end
          @win.keypad(true)

          # Translate the X axis title string to a chtype array
          xtitle_len = []
          xtitle_pos = []
          if xtitle&.size&.positive?
            @xtitle = Slithernix::Cdk.char_to_chtype(
              xtitle,
              xtitle_len,
              xtitle_pos,
            )
            @xtitle_len = xtitle_len[0]
          else
            @xtitle = Slithernix::Cdk.char_to_chtype(
              '<C></5>X Axis',
              xtitle_len,
              xtitle_pos,
            )
            @xtitle_len = title_len[0]
          end
          @xtitle_pos = Slithernix::Cdk.justify_string(
            @box_height,
            @xtitle_len,
            xtitle_pos[0],
          )

          # Translate the Y Axis title string to a chtype array
          ytitle_len = []
          ytitle_pos = []
          @ytitle = if ytitle&.size&.positive?
                      Slithernix::Cdk.char_to_chtype(
                        ytitle,
                        ytitle_len,
                        ytitle_pos,
                      )
                    else
                      Slithernix::Cdk.char_to_chtype(
                        '<C></5>Y Axis',
                        ytitle_len,
                        ytitle_pos,
                      )
                    end
          @ytitle_len = ytitle_len[0]
          @ytitle_pos = Slithernix::Cdk.justify_string(
            @box_width,
            @ytitle_len,
            ytitle_pos[0],
          )

          @graph_char = 0
          @values = []

          cdkscreen.register(:Graph, self)
        end

        # This was added for the builder.
        def activate(_actions)
          draw(@box)
        end

        # Set multiple attributes of the widget
        def set(values, count, graph_char, start_at_zero, display_type)
          ret = set_values(values, count, start_at_zero)
          set_characters(graph_char)
          set_display_type(display_type)
          ret
        end

        # Set the scale factors for the graph after wee have loaded new values.
        def set_scales
          @xscale = (@maxx - @minx) / [1, @box_height - @title_lines - 5].max
          @xscale = 1 if @xscale <= 0

          @yscale = (@box_width - 4) / [1, @count].max
          @yscale = 1 if @yscale <= 0
        end

        # Set the values of the graph.
        def set_values(values, count, start_at_zero)
          min = 2**30
          max = -2**30

          # Make sure everything is happy.
          return false if count.negative?

          if @values&.size&.positive?
            @values = []
            @count = 0
          end

          # Copy the X values
          values.each do |value|
            min = [value, @minx].min
            max = [value, @maxx].max

            # Copy the value.
            @values << value
          end

          # Keep the count and min/max values
          @count = count
          @minx = min
          @maxx = max

          # Check the start at zero status.
          @minx = 0 if start_at_zero

          set_scales

          true
        end

        def get_values(size)
          size << @count
          @values
        end

        # Set the value of the graph at the given index.
        def set_value(index, value, start_at_zero)
          # Make sure the index is within range.
          return false if index.negative? || index >= @count

          # Set the min, max, and value for the graph
          @minx = [value, @minx].min
          @maxx = [value, @maxx].max
          @values[index] = value

          # Check the start at zero status
          @minx = 0 if start_at_zero

          set_scales

          true
        end

        def get_value(index)
          index >= 0 and index < @count ? @values[index] : 0
        end

        # Set the characters of the graph widget.
        def set_characters(characters)
          char_count = []
          new_tokens = Slithernix::Cdk.char_to_chtype(
            characters,
            char_count,
            [],
          )

          return false if char_count[0] != @count

          @graph_char = new_tokens
          true
        end

        def get_characters
          @graph_char
        end

        # Set the character of the graph widget of the given index.
        def set_character(index, character)
          # Make sure the index is within range
          return false if index.negative? || index > @count

          # Convert the string given to us
          char_count = []
          new_tokens = Slithernix::Cdk.char_to_chtype(
            character,
            char_count,
            [],
          )

          # Check if the number of characters back is the same as the number
          # of elements in the list.
          return false if char_count[0] != @count

          # Everything OK so far. Set the value of the array.
          @graph_char[index] = new_tokens[0]
          true
        end

        def get_character(index)
          graph_char[index]
        end

        # Set the display type of the graph.
        def set_display_type(type)
          @display_type = type
        end

        def get_display_type
          @display_type
        end

        # Set the background attribute of the widget.
        def set_background_attr(attrib)
          @win.wbkgd(attrib)
        end

        # Move the graph field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          current_x = @win.begx
          current_y = @win.begy
          xpos = xplace
          ypos = yplace

          # If this is a relative move, then we will adjust where we want
          # to move to
          if relative
            xpos = @win.begx + xplace
            ypos = @win.begy + yplace
          end

          # Adjust the window if we need to.
          xtmp = [xpos]
          [ypos]
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

          # Touch the windows so they 'move'.
          Slithernix::Cdk::Screen.refresh_window(@screen.window)

          # Reraw the windowk if they asked for it
          draw(@box) if refresh_flag
        end

        # Draw the grpah widget
        def draw(box)
          adj = 2 + (@xtitle.nil? || @xtitle.empty? ? 0 : 1)
          spacing = 0
          attrib = ' '.ord | Curses::A_REVERSE

          Slithernix::Cdk::Draw.draw_obj_box(@win, self) if box

          # Draw in the vertical axis
          Slithernix::Cdk::Draw.draw_line(
            @win,
            2,
            @title_lines + 1,
            2,
            @box_height - 3,
            Slithernix::Cdk::ACS_VLINE,
          )

          # Draw in the horizontal axis
          Slithernix::Cdk::Draw.draw_line(
            @win,
            3,
            @box_height - 3,
            @box_width,
            @box_height - 3,
            Slithernix::Cdk::ACS_HLINE,
          )

          draw_title(@win)

          # Draw in the X axis title.
          if @xtitle&.size&.positive?
            Slithernix::Cdk::Draw.write_chtype(
              @win,
              0,
              @xtitle_pos,
              @xtitle,
              Slithernix::Cdk::VERTICAL,
              0,
              @xtitle_len,
            )
            attrib = @xtitle[0] & Curses::A_ATTRIBUTES
          end

          # Draw in the X axis high value
          temp = format('%d', @maxx)
          Slithernix::Cdk::Draw.write_char_attrib(
            @win,
            1,
            @title_lines + 1,
            temp,
            attrib,
            Slithernix::Cdk::VERTICAL,
            0,
            temp.size,
          )

          # Draw in the X axis low value.
          temp = format('%d', @minx)
          Slithernix::Cdk::Draw.write_char_attrib(
            @win,
            1,
            @box_height - 2 - temp.size,
            temp,
            attrib,
            Slithernix::Cdk::VERTICAL,
            0,
            temp.size,
          )

          # Draw in the Y axis title
          if @ytitle&.size&.positive?
            Slithernix::Cdk::Draw.write_chtype(
              @win,
              @ytitle_pos,
              @box_height - 1,
              @ytitle,
              Slithernix::Cdk::HORIZONTAL,
              0,
              @ytitle_len,
            )
          end

          # Draw in the Y axis high value.
          temp = format('%d', @count)
          Slithernix::Cdk::Draw.write_char_attrib(
            @win,
            @box_width - temp.size - adj,
            @box_height - 2,
            temp,
            attrib,
            Slithernix::Cdk::HORIZONTAL,
            0,
            temp.size,
          )

          # Draw in the Y axis low value.
          Slithernix::Cdk::Draw.write_char_attrib(
            @win,
            3,
            @box_height - 2,
            '0',
            attrib,
            Slithernix::Cdk::HORIZONTAL,
            0,
            '0'.size
          )

          # If the count is zero then there aren't any points.
          if @count.zero?
            @win.refresh
            return
          end

          spacing = (@box_width - 3) / @count # FIXME: magic number (TITLE_LM)

          # Draw in the graph line/plot points.
          (0...@count).each do |y|
            colheight = (@values[y] / @xscale) - 1
            # Add the marker on the Y axis.
            @win.mvwaddch(
              @box_height - 3,
              ((y + 1) * spacing) + adj,
              Slithernix::Cdk::ACS_TTEE,
            )

            # If this is a plot graph, all we do is draw a dot.
            if @display_type == :PLOT
              xpos = @box_height - 4 - colheight
              ypos = ((y + 1) * spacing) + adj
              @win.mvwaddch(xpos, ypos, @graph_char[y])
            else
              (0..@yscale).each do |_x|
                xpos = @box_height - 3
                ypos = ((y + 1) * spacing) - adj
                Slithernix::Cdk::Draw.draw_line(
                  @win,
                  ypos,
                  xpos - colheight,
                  ypos,
                  xpos,
                  @graph_char[y],
                )
              end
            end
          end

          # Draw in the axis corners.
          @win.mvwaddch(@title_lines, 2, Slithernix::Cdk::ACS_URCORNER)
          @win.mvwaddch(@box_height - 3, 2, Slithernix::Cdk::ACS_LLCORNER)
          @win.mvwaddch(
            @box_height - 3,
            @box_width,
            Slithernix::Cdk::ACS_URCORNER
          )

          # Refresh and lets see it
          @win.refresh
        end

        def destroy
          clean_title
          clean_bindings(:Graph)
          Slithernix::Cdk::Screen.unregister(:Graph, self)
          Slithernix::Cdk.delete_curses_window(@win)
        end

        def erase
          Slithernix::Cdk.erase_curses_window(@win) if is_valid_widget?
        end

        def position
          super(@win)
        end
      end
    end
  end
end
