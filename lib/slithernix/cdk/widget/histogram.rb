# frozen_string_literal: true

require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class Histogram < Slithernix::Cdk::Widget
        def initialize(cdkscreen, xplace, yplace, height, width, orient, title, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy

          set_box(box)

          box_height = Slithernix::Cdk.set_widget_dimension(
            parent_height,
            height,
            2
          )
          old_height = box_height
          box_width = Slithernix::Cdk.set_widget_dimension(
            parent_width,
            width,
            0
          )

          old_width = box_width

          box_width = set_title(title, -(box_width + 1))

          # increment the height by number of lines in in the title
          box_height += @title_lines

          # Make sure we didn't extend beyond the dimensions of the window.
          box_width = old_width if box_width > parent_width
          box_height = old_height if box_height > parent_height

          # Rejustify the x and y positions if we need to.
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

          # Set up the histogram data
          @screen = cdkscreen
          @parent = cdkscreen.window
          @win = Curses::Window.new(box_height, box_width, ypos, xpos)
          @shadow_win = nil
          @box_width = box_width
          @box_height = box_height
          @field_width = box_width - (2 * @border_size)
          @field_height = box_height - @title_lines - (2 * @border_size)
          @orient = orient
          @shadow = shadow

          # Is the window nil
          if @win.nil?
            destroy
            return nil
          end

          @win.keypad(true)

          # Set up some default values.
          @filler = '#'.ord | Curses::A_REVERSE
          @stats_attr = Curses::A_NORMAL
          @stats_pos = Slithernix::Cdk::TOP
          @view_type = :REAL
          @high = 0
          @low = 0
          @value = 0
          @lowx = 0
          @lowy = 0
          @highx = 0
          @highy = 0
          @curx = 0
          @cury = 0
          @low_string = String.new
          @high_string = String.new
          @cur_string = String.new

          # Do we want a shadow?
          if shadow
            @shadow_win = Curses::Window.new(
              box_height,
              box_width,
              ypos + 1,
              xpos + 1,
            )
          end

          cdkscreen.register(:Histogram, self)
        end

        # This was added for the builder
        def activate(_actions)
          draw(@box)
        end

        # Set various widget attributes
        def set(view_type, stats_pos, stats_attr, low, high, value, filler, box)
          set_display_type(view_type)
          set_stats_pos(stats_pos)
          set_value(low, high, value)
          set_filler_char(filler)
          set_stats_attr(stats_attr)
          set_box(box)
        end

        # Set the values for the widget.
        def set_value(low, high, value)
          # We should error check the information we have.
          @low = low <= high ? low : 0
          @high = low <= high ? high : 0
          @value = low <= value && value <= high ? value : 0
          # Determine the percentage of the given value.
          @percent = @high.zero? ? 0 : (1.0 * (@value / @high))

          # Determine the size of the histogram bar.
          @bar_size = if @orient == Slithernix::Cdk::VERTICAL
                        @percent * @field_height
                      else
                        @percent * @field_width
                      end

          # We have a number of variables which determine the personality of the
          # histogram.  We have to go through each one methodically, and set them
          # correctly.  This section does this.
          return unless @view_type != :NONE

          if @orient == Slithernix::Cdk::VERTICAL
            case @stats_pos
            when Slithernix::Cdk::LEFT, Slithernix::Cdk::BOTTOM
              # Set the low label attributes.
              @low_string = @low.to_s
              @lowx = 1
              @lowy = @box_height - @low_string.size - 1

              # Set the high label attributes
              @high_string = @high.to_s
              @highx = 1
              @highy = @title_lines + 1
              # Set the current value attributes.
              string = if @view_type == :PERCENT
                       then format('%3.1f%%', 1.0 * @percent * 100)
                       elsif @view_type == :FRACTION
                         format('%d/%d', @value, @high)
                       else
                         @value.to_s
                       end
              @cur_string = string
              @curx = 1
              @cury = ((@field_height - string.size) / 2) + @title_lines + 1
            when Slithernix::Cdk::CENTER
              # Set the lower label attributes
              @low_string = @low.to_s
              @lowx = (@field_width / 2) + 1
              @lowy = @box_height - @low_string.size - 1

              # Set the high label attributes
              @high_string = @high.to_s
              @highx = (@field_width / 2) + 1
              @highy = @title_lines + 1

              # Set the stats label attributes
              string = if @view_type == :PERCENT
                       then format('%3.2f%%', 1.0 * @percent * 100)
                       elsif @view_type == :FRACTIOn
                         format('%d/%d', @value, @high)
                       else
                         @value.to_s
                       end

              @cur_string = string
              @curx = (@field_width / 2) + 1
              @cury = ((@field_height - string.size) / 2) + @title_lines + 1
            when Slithernix::Cdk::RIGHT, Slithernix::Cdk::TOP
              # Set the low label attributes.
              @low_string = @low.to_s
              @lowx = @field_width
              @lowy = @box_height - @low_string.size - 1

              # Set the high label attributes.
              @high_string = @high.to_s
              @highx = @field_width
              @highy = @title_lines + 1

              # Set the stats label attributes.
              string = if @view_type == :PERCENT
                       then format('%3.2f%%', 1.0 * @percent * 100)
                       elsif @view_type == :FRACTION
                         format('%d/%d', @value, @high)
                       else
                         @value.to_s
                       end
              @cur_string = string
              @curx = @field_width
              @cury = ((@field_height - string.size) / 2) + @title_lines + 1
            end
          elsif @stats_pos == Slithernix::Cdk::TOP || @stats_pos == Slithernix::Cdk::RIGHT
            # Alignment is HORIZONTAL
            @low_string = @low.to_s
            @lowx = 1
            @lowy = @title_lines + 1

            # Set the high label attributes.
            @high_string = @high.to_s
            @highx = @box_width - @high_string.size - 1
            @highy = @title_lines + 1

            # Set the stats label attributes.
            string = if @view_type == :PERCENT
                     then format('%3.1f%%', 1.0 * @percent * 100)
                     elsif @view_type == :FRACTION
                       format('%d/%d', @value, @high)
                     else
                       @value.to_s
                     end
            @cur_string = string
            @curx = ((@field_width - @cur_string.size) / 2) + 1
            @cury = @title_lines + 1
          # Set the low label attributes.
          elsif @stats_pos == Slithernix::Cdk::CENTER
            # Set the low label attributes.
            @low_string = @low.to_s
            @lowx = 1
            @lowy = (@field_height / 2) + @title_lines + 1

            # Set the high label attributes.
            @high_string = @high.to_s
            @highx = @box_width - @high_string.size - 1
            @highy = (@field_height / 2) + @title_lines + 1

            # Set the stats label attributes.
            string = if @view_type == :PERCENT
                     then format('%3.1f%%', 1.0 * @percent * 100)
                     elsif @view_type == :FRACTION
                       format('%d/%d', @value, @high)
                     else
                       @value.to_s
                     end
            @cur_string = string
            @curx = ((@field_width - @cur_string.size) / 2) + 1
            @cury = (@field_height / 2) + @title_lines + 1
          elsif @stats_pos == Slithernix::Cdk::BOTTOM || @stats_pos == Slithernix::Cdk::LEFT
            # Set the low label attributes.
            @low_string = @low.to_s
            @lowx = 1
            @lowy = @box_height - (2 * @border_size)

            # Set the high label attributes.
            @high_string = @high.to_s
            @highx = @box_width - @high_string.size - 1
            @highy = @box_height - (2 * @border_size)

            # Set the stats label attributes.
            string = if @view_type == :PERCENT
                     then format('%3.1f%%', 1.0 * @percent * 100)
                     elsif @view_type == :FRACTION
                       format('%d/%d', @value, @high)
                     else
                       @value.to_s
                     end
            @cur_string = string
            @curx = ((@field_width - @cur_string.size) / 2) + 1
            @cury = @box_height - (2 * @border_size)
          end
        end

        def get_value
          @value
        end

        def get_low_value
          @low
        end

        def get_high_value
          @high
        end

        # Set the histogram display type
        def set_display_type(view_type)
          @view_type = view_type
        end

        def get_view_type
          @view_type
        end

        # Set the position of the statistics information.
        def set_stats_pos(stats_pos)
          @stats_pos = stats_pos
        end

        def get_stats_pos
          @stats_pos
        end

        # Set the attribute of the statistics.
        def set_stats_attr(stats_attr)
          @stats_attr = stats_attr
        end

        def get_stats_attr
          @stats_attr
        end

        # Set the character to use when drawing the widget.
        def set_filler_char(character)
          @filler = character
        end

        def get_filler_char
          @filler
        end

        # Set the background attribute of the widget.
        def set_background_attr(attrib)
          @win.wbkgd(attrib)
        end

        # Move the histogram field to the given location.
        # Inherited
        # def move(xplace, yplace, relative, refresh_flag)
        # end

        # Draw the widget.
        def draw(box)
          battr = 0
          fattr = @filler & Curses::A_ATTRIBUTES
          hist_x = @title_lines + 1
          hist_y = @bar_size

          @win.erase

          # Box the widget if asked.
          Slithernix::Cdk::Draw.draw_obj_box(@win, self) if box

          # Do we have a shadow to draw?
          Slithernix::Cdk::Draw.draw_shadow(@shadow_win) unless @shadow.nil?

          draw_title(@win)

          # If the user asked for labels, draw them in.
          if @view_type != :NONE
            # Draw in the low label.
            if @low_string.size.positive?
              Slithernix::Cdk::Draw.write_char_attrib(
                @win,
                @lowx,
                @lowy,
                @low_string,
                @stats_attr,
                @orient,
                0,
                @low_string.size
              )
            end

            # Draw in the current value label.
            if @cur_string.size.positive?
              Slithernix::Cdk::Draw.write_char_attrib(
                @win,
                @curx,
                @cury,
                @cur_string,
                @stats_attr,
                @orient,
                0,
                @cur_string.size
              )
            end

            # Draw in the high label.
            if @high_string.size.positive?
              Slithernix::Cdk::Draw.write_char_attrib(
                @win,
                @highx,
                @highy,
                @high_string,
                @stats_attr,
                @orient,
                0,
                @high_string.size
              )
            end
          end

          if @orient == Slithernix::Cdk::VERTICAL
            hist_x = @box_height - @bar_size - 1
            hist_y = @field_width
          end

          # Draw the histogram bar.
          (hist_x...@box_height - 1).to_a.each do |x|
            (1..hist_y).each do |y|
              battr = @win.mvinch(x, y)

              if battr == ' '.ord
                @win.mvwaddch(x, y, @filler)
              else
                @win.mvwaddch(x, y, battr | fattr)
              end
            end
          end

          # Refresh the window
          @win.refresh
        end

        # Destroy the widget.
        def destroy
          clean_title

          # Clean up the windows.
          Slithernix::Cdk.delete_curses_window(@shadow_win)
          Slithernix::Cdk.delete_curses_window(@win)

          # Clean the key bindings.
          clean_bindings(:Histogram)

          # Unregister this widget.
          Slithernix::Cdk::Screen.unregister(:Histogram, self)
        end

        # Erase the widget from the screen.
        def erase
          return unless is_valid_widget?

          Slithernix::Cdk.erase_curses_window(@win)
          Slithernix::Cdk.erase_curses_window(@shadow_win)
        end
      end
    end
  end
end
