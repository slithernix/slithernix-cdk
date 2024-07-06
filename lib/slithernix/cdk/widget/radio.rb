require_relative 'scroller'

module Slithernix
  module Cdk
    class Widget
      class Radio < Slithernix::Cdk::Widget::Scroller
        def initialize(cdkscreen, xplace, yplace, splace, height, width,
                       title, list, list_size, choice_char, def_item, highlight, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          box_width = width
          box_height = height
          widest_item = 0

          bindings = {
            'g' => Curses::KEY_HOME,
            '1' => Curses::KEY_HOME,
            'G' => Curses::KEY_END,
            '<' => Curses::KEY_HOME,
            '>' => Curses::KEY_END
          }

          bindings[Slithernix::Cdk::BACKCHAR] = Curses::KEY_PPAGE
          bindings[Slithernix::Cdk::FORCHAR]  = Curses::KEY_NPAGE
          setBox(box)

          # If the height is a negative value, height will be ROWS-height,
          # otherwise the height will be the given height.
          box_height = Slithernix::Cdk.setWidgetDimension(
            parent_height,
            height,
            0,
          )

          # If the width is a negative value, the width will be COLS-width,
          # otherwise the width will be the given width.
          box_width = Slithernix::Cdk.setWidgetDimension(
            parent_width,
            width,
            5,
          )

          box_width = setTitle(title, box_width)

          # Set the box height.
          if @title_lines > box_height
            box_height = @title_lines + [list_size, 8].min + (2 * @border_size)
          end

          # Adjust the box width if there is a scroll bar.
          scrollbar = false

          if [Slithernix::Cdk::LEFT, Slithernix::Cdk::RIGHT].include?(splace)
            box_width += 1
            @scrollbar = true
          end

          # Make sure we didn't extend beyond the dimensions of the window
          @box_width = [box_width, parent_width].min
          @box_height = [box_height, parent_height].min

          setViewSize(list_size)

          # Each item in the needs to be converted to chtype array
          widest_item = createList(list, list_size, @box_width)
          if widest_item.positive?
            updateViewWidth(widest_item)
          elsif list_size.positive?
            destroy
            return nil
          end

          # Rejustify the x and y positions if we need to.
          xtmp = [xplace]
          ytmp = [yplace]
          Slithernix::Cdk.alignxy(
            cdkscreen.window,
            xtmp,
            ytmp,
            @box_width,
            @box_height,
          )

          xpos = xtmp[0]
          ypos = ytmp[0]

          # Make the radio window
          @win = Curses::Window.new(@box_height, @box_width, ypos, xpos)

          # Is the window nil?
          if @win.nil?
            destroy
            raise StandardError, "could not create curses window"
          end

          # Turn on the keypad.
          @win.keypad(true)

          # Create the scrollbar window.
          if splace == Slithernix::Cdk::RIGHT
            @scrollbar_win = @win.subwin(
              maxViewSize,
              1,
              self.SCREEN_YPOS(ypos),
              xpos + @box_width - @border_size - 1,
            )
          elsif splace == Slithernix::Cdk::LEFT
            @scrollbar_win = @win.subwin(
              maxViewSize,
              1,
              self.SCREEN_YPOS(ypos),
              self.SCREEN_XPOS(xpos),
            )
          else
            @scrollbar_win = nil
          end

          # Set the rest of the variables
          @screen = cdkscreen
          @parent = cdkscreen.window
          @scrollbar_placement = splace
          @widest_item = widest_item
          @left_char = 0
          @selected_item = 0
          @highlight = highlight
          @choice_char = choice_char.ord
          @left_box_char = '['.ord
          @right_box_char = ']'.ord
          @def_item = def_item
          @input_window = @win
          @accepts_focus = true
          @shadow = shadow

          setCurrentItem(0)

          # Do we need to create the shadow?
          if shadow
            @shadow_win = Curses::Window.new(box_height, box_width + 1,
                                             ypos + 1, xpos + 1)
          end

          # Setup the key bindings
          bindings.each do |from, to|
            bind(:Radio, from, :getc, to)
          end

          cdkscreen.register(:Radio, self)
        end

        # Put the cursor on the currently-selected item.
        def fixCursorPosition
          scrollbar_adj = @scrollbar_placement == Slithernix::Cdk::LEFT ? 1 : 0
          ypos = self.SCREEN_YPOS(@current_item - @current_top)
          xpos = self.SCREEN_XPOS(0) + scrollbar_adj

          # @input_window.move(ypos, xpos)
          @input_window.refresh
        end

        # This actually manages the radio widget.
        def activate(actions)
          # Draw the radio list.
          draw(@box)

          if actions.nil? || actions.size.zero?
            while true
              fixCursorPosition
              input = getch([])

              # Inject the character into the widget.
              ret = inject(input)
              return ret if @exit_type != :EARLY_EXIT
            end
          else
            actions.each do |action|
              ret = inject(action)
              return ret if @exit_type != :EARLY_EXIT
            end
          end

          # Set the exit type and return
          setExitType(0)
          -1
        end

        # This injects a single character into the widget.
        def inject(input)
          pp_return = 1
          ret = -1
          complete = false

          # Set the exit type
          setExitType(0)

          # Draw the widget list
          drawList(@box)

          # Check if there is a pre-process function to be called
          unless @pre_process_func.nil?
            # Call the pre-process function.
            pp_return = @pre_process_func.call(
              :Radio,
              self,
              @pre_process_data,
              input,
            )
          end

          # Should we continue?
          if pp_return != 0
            # Check for a predefined key binding.
            if checkBind(:Radio, input)
              complete = true
            else
              case input
              when Curses::KEY_UP
                self.KEY_UP
              when Curses::KEY_DOWN
                self.KEY_DOWN
              when Curses::KEY_RIGHT
                self.KEY_RIGHT
              when Curses::KEY_LEFT
                self.KEY_LEFT
              when Curses::KEY_PPAGE
                self.KEY_PPAGE
              when Curses::KEY_NPAGE
                self.KEY_NPAGE
              when Curses::KEY_HOME
                self.KEY_HOME
              when Curses::KEY_END
                self.KEY_END
              when '$'
                @left_char = @max_left_char
              when '|'
                @left_char = 0
              when ' '
                @selected_item = @current_item
              when Slithernix::Cdk::KEY_ESC
                setExitType(input)
                ret = -1
                complete = true
              when Curses::Error
                setExitType(input)
                complete = true
              when Slithernix::Cdk::KEY_TAB, Slithernix::Cdk::KEY_RETURN, Curses::KEY_ENTER
                setExitType(input)
                ret = @selected_item
                complete = true
              when Slithernix::Cdk::REFRESH
                @screen.erase
                @screen.refresh
              end
            end

            # Should we call a post-process?
            if !complete && @post_process_func
              @post_process_func.call(:Radio, self, @post_process_data, input)
            end
          end

          unless complete
            drawList(@box)
            setExitType(0)
          end

          fixCursorPosition
          @return_data = ret
          ret
        end

        # This moves the radio field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@win, @scrollbar_win, @shadow_win]
          move_specific(xplace, yplace, relative, refresh_flag,
                        windows, subwidgets)
        end

        # This function draws the radio widget.
        def draw(_box)
          # Do we need to draw in the shadow?
          Slithernix::Cdk::Draw.drawShadow(@shadow_win) unless @shadow_win.nil?

          drawTitle(@win)

          # Draw in the radio list.
          drawList(@box)
        end

        # This redraws the radio list.
        def drawList(box)
          scrollbar_adj = @scrollbar_placement == Slithernix::Cdk::LEFT ? 1 : 0
          screen_pos = 0

          # Draw the list
          (0...@view_size).each do |j|
            k = j + @current_top
            next unless k < @list_size

            xpos = self.SCREEN_XPOS(0)
            ypos = self.SCREEN_YPOS(j)

            screen_pos = self.SCREENPOS(k, scrollbar_adj)

            # Draw the empty string.
            Slithernix::Cdk::Draw.writeBlanks(@win, xpos, ypos, Slithernix::Cdk::HORIZONTAL, 0,
                                              @box_width - @border_size)

            # Draw the line.
            Slithernix::Cdk::Draw.writeChtype(
              @win,
              screen_pos >= 0 ? screen_pos : 1,
              ypos,
              @item[k],
              Slithernix::Cdk::HORIZONTAL,
              screen_pos >= 0 ? 0 : (1 - screen_pos),
              @item_len[k],
            )

            # Draw the selected choice
            xpos += scrollbar_adj
            @win.mvwaddch(ypos, xpos, @left_box_char)
            @win.mvwaddch(
              ypos,
              xpos + 1,
              k == @selected_item ? @choice_char : ' '.ord,
            )
            @win.mvwaddch(ypos, xpos + 2, @right_box_char)
          end

          # Highlight the current item
          if @has_focus
            k = @current_item
            if k < @list_size
              screen_pos = self.SCREENPOS(k, scrollbar_adj)
              ypos = self.SCREEN_YPOS(@current_high)

              Slithernix::Cdk::Draw.writeChtypeAttrib(
                @win,
                screen_pos >= 0 ? screen_pos : (1 + scrollbar_adj),
                ypos,
                @item[k],
                @highlight,
                Slithernix::Cdk::HORIZONTAL,
                screen_pos >= 0 ? 0 : (1 - screen_pos),
                @item_len[k],
              )
            end
          end

          if @scrollbar
            @toggle_pos = (@current_item * @step).floor
            @toggle_pos = [@toggle_pos, @scrollbar_win.maxy - 1].min

            @scrollbar_win.mvwvline(
              0,
              0,
              Slithernix::Cdk::ACS_CKBOARD,
              @scrollbar_win.maxy,
            )

            @scrollbar_win.mvwvline(
              @toggle_pos,
              0,
              ' '.ord | Curses::A_REVERSE,
              @toggle_size,
            )
          end

          # Box it if needed.
          Slithernix::Cdk::Draw.drawObjBox(@win, self) if box

          fixCursorPosition
        end

        # This sets the background attribute of the widget.
        def setBKattr(attrib)
          @win.wbkgd(attrib)
          @scrollbar_win.wbkgd(attrib) unless @scrollbar_win.nil?
        end

        def destroyInfo
          @item = ''
        end

        # This function destroys the radio widget.
        def destroy
          cleanTitle
          destroyInfo

          # Clean up the windows.
          Slithernix::Cdk.deleteCursesWindow(@scrollbar_win)
          Slithernix::Cdk.deleteCursesWindow(@shadow_win)
          Slithernix::Cdk.deleteCursesWindow(@win)

          # Clean up the key bindings.
          cleanBindings(:Radio)

          # Unregister this widget.
          Slithernix::Cdk::Screen.unregister(:Radio, self)
        end

        # This function erases the radio widget
        def erase
          return unless validCDKObject

          Slithernix::Cdk.eraseCursesWindow(@win)
          Slithernix::Cdk.eraseCursesWindow(@shadow_win)
        end

        # This sets various attributes of the radio list.
        def set(highlight, choice_char, box)
          setHighlight(highlight)
          setChoiceCHaracter(choice_char)
          setBox(box)
        end

        # This sets the radio list items.
        def setItems(list, list_size)
          widest_item = createList(list, list_size, @box_width)
          return if widest_item <= 0

          # Clean up the display.
          (0...@view_size).each do |j|
            Slithernix::Cdk::Draw.writeBlanks(
              @win,
              self.SCREEN_XPOS(0),
              self.SCREEN_YPOS(j),
              Slithernix::Cdk::HORIZONTAL,
              0,
              @box_width - @border_size,
            )
          end

          setViewSize(list_size)

          setCurrentItem(0)
          @left_char = 0
          @selected_item = 0

          updateViewWidth(widest_item)
        end

        def getItems(list)
          (0...@list_size).each do |j|
            list << Slithernix::Cdk.chtype2Char(@item[j])
          end
          @list_size
        end

        # This sets the highlight bar of the radio list.
        def setHighlight(highlight)
          @highlight = highlight
        end

        def getHighlight
          @highlight
        end

        # This sets the character to use when selecting na item in the list.
        def setChoiceCharacter(character)
          @choice_char = character
        end

        def getChoiceCharacter
          @choice_char
        end

        # This sets the character to use to drw the left side of the choice box
        # on the list
        def setLeftBrace(character)
          @left_box_char = character
        end

        def getLeftBrace
          @left_box_char
        end

        # This sets the character to use to draw the right side of the choice box
        # on the list
        def setRightBrace(character)
          @right_box_char = character
        end

        def getRightBrace
          @right_box_char
        end

        # This sets the current highlighted item of the widget
        def setCurrentItem(item)
          setPosition(item)
          @selected_item = item
        end

        def getCurrentItem
          @current_item
        end

        # This sets the selected item of the widget
        def setSelectedItem(item)
          @selected_item = item
        end

        def getSelectedItem
          @selected_item
        end

        def focus
          drawList(@box)
        end

        def unfocus
          drawList(@box)
        end

        def createList(list, list_size, box_width)
          status = false
          widest_item = 0

          if list_size >= 0
            new_list = []
            new_len = []
            new_pos = []

            # Each item in the needs to be converted to chtype array
            status = true
            box_width -= 2 + @border_size
            (0...list_size).each do |j|
              lentmp = []
              postmp = []
              new_list << Slithernix::Cdk.char2Chtype(list[j], lentmp, postmp)
              new_len << lentmp[0]
              new_pos << postmp[0]
              if new_list[j].nil? || new_list[j].size.zero?
                status = false
                break
              end
              new_pos[j] =
                Slithernix::Cdk.justifyString(box_width, new_len[j],
                                              new_pos[j]) + 3
              widest_item = [widest_item, new_len[j]].max
            end
            if status
              destroyInfo
              @item = new_list
              @item_len = new_len
              @item_pos = new_pos
            end
          end

          (status ? widest_item : 0)
        end

        # Determine how many characters we can shift to the right
        # before all the items have been scrolled off the screen.
        def AvailableWidth
          @box_width - (2 * @border_size) - 3
        end

        def updateViewWidth(widest)
          @max_left_char = if @box_width > widest
                           then 0
                           else
                             widest - self.AvailableWidth
                           end
        end

        def WidestItem
          @max_left_char + self.AvailableWidth
        end

        def SCREENPOS(n, scrollbar_adj)
          @item_pos[n] - @left_char + scrollbar_adj + @border_size
        end
      end
    end
  end
end
