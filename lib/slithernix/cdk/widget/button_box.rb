require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class ButtonBox < Slithernix::Cdk::Widget
        attr_reader :current_button

        def initialize(cdkscreen, x_pos, y_pos, height, width, title, rows, cols,
                       buttons, button_count, highlight, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          col_width = 0
          current_button = 0
          @button = []
          @button_len = []
          @button_pos = []
          @column_widths = []

          if button_count <= 0
            destroy
            return nil
          end

          setBox(box)

          # Set some default values for the widget.
          @row_adjust = 0
          @col_adjust = 0

          # If the height is a negative value, the height will be
          # ROWS-height, otherwise the height will be the given height.
          box_height = Slithernix::Cdk.setWidgetDimension(parent_height,
                                                          height, rows + 1)

          # If the width is a negative value, the width will be
          # COLS-width, otherwise the width will be the given width.
          box_width = Slithernix::Cdk.setWidgetDimension(parent_width, width,
                                                         0)

          box_width = setTitle(title, box_width)

          # Translate the buttons string to a chtype array
          (0...button_count).each do |x|
            button_len = []
            @button << Slithernix::Cdk.char2Chtype(buttons[x], button_len, [])
            @button_len << button_len[0]
          end

          # Set the button positions.
          (0...cols).each do |_x|
            max_col_width = -2**31

            # Look for the widest item in this column.
            (0...rows).each do |_y|
              next unless current_button < button_count

              max_col_width = [@button_len[current_button],
                               max_col_width].max
              current_button += 1
            end

            # Keep the maximum column width for this column.
            @column_widths << max_col_width
            col_width += max_col_width
          end
          box_width += 1

          # Make sure we didn't extend beyond the dimensions of the window.
          box_width = [box_width, parent_width].min
          box_height = [box_height, parent_height].min

          # Now we have to readjust the x and y positions
          xtmp = [x_pos]
          ytmp = [y_pos]
          Slithernix::Cdk.alignxy(cdkscreen.window, xtmp, ytmp, box_width,
                                  box_height)
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Set up the buttonbox box attributes.
          @screen = cdkscreen
          @parent = cdkscreen.window
          @win = Curses::Window.new(box_height, box_width, ypos, xpos)
          @shadow_win = nil
          @button_count = button_count
          @current_button = 0
          @rows = rows
          @cols = [button_count, cols].min
          @box_height = box_height
          @box_width = box_width
          @highlight = highlight
          @accepts_focus = true
          @input_window = @win
          @shadow = shadow
          @button_attrib = Curses::A_NORMAL

          # Set up the row adjustment.
          if (box_height - rows - @title_lines).positive?
            @row_adjust = (box_height - rows - @title_lines) / @rows
          end

          # Set the col adjustment
          if (box_width - col_width).positive?
            @col_adjust = ((box_width - col_width) / @cols) - 1
          end

          # If we couldn't create the window, we should return a null value.
          if @win.nil?
            destroy
            return nil
          end
          @win.keypad(true)

          # Was there a shadow?
          if shadow
            @shadow_win = Curses::Window.new(
              box_height,
              box_width,
              ypos + 1,
              xpos + 1,
            )
          end

          # Register this baby.
          cdkscreen.register(:ButtonBox, self)
        end

        # This activates the widget.
        def activate(actions)
          # Draw the buttonbox box.
          draw(@box)

          if actions.nil? || actions.size.zero?
            while true
              input = getch([])

              # Inject the characer into the widget.
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

          # Set the exit type and exit
          setExitType(0)
          -1
        end

        # This injects a single character into the widget.
        def inject(input)
          first_button = 0
          last_button = @button_count - 1
          pp_return = 1
          ret = -1
          complete = false

          # Set the exit type
          setExitType(0)

          unless @pre_process_func.nil?
            pp_return = @pre_process_func.call(:ButtonBox, self,
                                               @pre_process_data, input)
          end

          # Should we continue?
          if pp_return != 0
            # Check for a key binding.
            if checkBind(:ButtonBox, input)
              complete = true
            else
              case input
              when Curses::KEY_LEFT, Curses::KEY_BTAB, Curses::KEY_BACKSPACE
                if @current_button - @rows < first_button
                  @current_button = last_button
                else
                  @current_button -= @rows
                end
              when Curses::KEY_RIGHT, Slithernix::Cdk::KEY_TAB, ' '
                if @current_button + @rows > last_button
                  @current_button = first_button
                else
                  @current_button += @rows
                end
              when Curses::KEY_UP
                if @current_button - 1 < first_button
                  @current_button = last_button
                else
                  @current_button -= 1
                end
              when Curses::KEY_DOWN
                if @current_button + 1 > last_button
                  @current_button = first_button
                else
                  @current_button += 1
                end
              when Slithernix::Cdk::REFRESH
                @screen.erase
                @screen.refresh
              when Slithernix::Cdk::KEY_ESC
                setExitType(input)
                complete = true
              when Curses::Error
                setExitType(input)
                complete = true
              when Slithernix::Cdk::KEY_RETURN, Curses::KEY_ENTER
                setExitType(input)
                ret = @current_button
                complete = true
              end
            end

            if !complete and @post_process_func
              @post_process_func.call(:ButtonBox, self, @post_process_data,
                                      input)
            end

          end

          unless complete
            drawButtons
            setExitType(0)
          end

          @result_data = ret
          ret
        end

        # This sets multiple attributes of the widget.
        def set(highlight, box)
          setHighlight(highlight)
          setBox(box)
        end

        # This sets the highlight attribute for the buttonboxes
        def setHighlight(highlight)
          @highlight = highlight
        end

        def getHighlight
          @highlight
        end

        # This sets th background attribute of the widget.
        def setBKattr(attrib)
          @win.wbkgd(attrib)
        end

        # This draws the buttonbox box widget.
        def draw(box)
          # Is there a shadow?
          Slithernix::Cdk::Draw.drawShadow(@shadow_win) unless @shadow_win.nil?

          # Box the widget if they asked.
          Slithernix::Cdk::Draw.drawObjBox(@win, self) if box

          # Draw in the title if there is one.
          drawTitle(@win)

          # Draw in the buttons.
          drawButtons
        end

        # This draws the buttons on the button box widget.
        def drawButtons
          row = @title_lines + 1
          col = @col_adjust / 2
          current_button = 0
          cur_row = -1
          cur_col = -1

          # Draw the buttons.
          while current_button < @button_count
            (0...@cols).each do |x|
              row = @title_lines + @border_size

              (0...@rows).each do |_y|
                attr = @button_attrib
                if current_button == @current_button
                  attr = @highlight
                  cur_row = row
                  cur_col = col
                end

                Slithernix::Cdk::Draw.writeChtypeAttrib(
                  @win,
                  col,
                  row,
                  @button[current_button],
                  attr,
                  Slithernix::Cdk::HORIZONTAL,
                  0,
                  @button_len[current_button],
                )

                row += (1 + @row_adjust)
                current_button += 1
              end
              col += @column_widths[x] + @col_adjust + @border_size
            end
          end

          # This seems to just cause the window display to be all messed up
          # if cur_row >= 0 && cur_col >= 0
          #  @win.move(cur_row, cur_col)
          # end
          @win.refresh
        end

        # This erases the buttonbox box from the screen.
        def erase
          return unless validCDKObject

          Slithernix::Cdk.eraseCursesWindow(@win)
          Slithernix::Cdk.eraseCursesWindow(@shadow_win)
        end

        # This destroys the widget
        def destroy
          cleanTitle

          Slithernix::Cdk.deleteCursesWindow(@shadow_win)
          Slithernix::Cdk.deleteCursesWindow(@win)

          cleanBindings(:ButtonBox)

          Slithernix::Cdk::Screen.unregister(:ButtonBox, self)
        end

        def setCurrentButton(button)
          @current_button = button if button >= 0 && button < @button_count
        end

        def getCurrentButton
          @current_button
        end

        def getButtonCount
          @button_count
        end

        def focus
          draw(@box)
        end

        def unfocus
          draw(@box)
        end

        def position
          super(@win)
        end
      end
    end
  end
end
