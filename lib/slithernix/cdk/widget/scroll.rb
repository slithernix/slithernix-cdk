# frozen_string_literal: true

require_relative 'scroller'

module Slithernix
  module Cdk
    class Widget
      class Scroll < Slithernix::Cdk::Widget::Scroller
        attr_reader :item, :list_size, :current_item, :highlight

        def initialize(cdkscreen, xplace, yplace, splace, height, width, title, list, list_size, numbers, highlight, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          xpos = xplace
          ypos = yplace
          scroll_adjust = 0
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

          # If the height is a negative value, the height will be ROWS-height,
          # otherwise the height will be the given height
          box_height = Slithernix::Cdk.setWidgetDimension(
            parent_height,
            height,
            0,
          )

          # If the width is a negative value, the width will be COLS-width,
          # otherwise the width will be the given width
          box_width = Slithernix::Cdk.setWidgetDimension(
            parent_width,
            width,
            0,
          )

          box_width = setTitle(title, box_width)

          # Set the box height.
          if @title_lines > box_height
            box_height = @title_lines + [list_size, 8].min + (2 * @border_size)
          end

          # Adjust the box width if there is a scroll bar
          if [Slithernix::Cdk::LEFT, Slithernix::Cdk::RIGHT].include?(splace)
            @scrollbar = true
            box_width += 1
          else
            @scrollbar = false
          end

          # Make sure we didn't extend beyond the dimensions of the window.
          @box_width = if box_width > parent_width
                       then parent_width - scroll_adjust
                       else
                         box_width
                       end
          @box_height = [box_height, parent_height].min

          setViewSize(list_size)

          # Rejustify the x and y positions if we need to.
          xtmp = [xpos]
          ytmp = [ypos]
          Slithernix::Cdk.alignxy(cdkscreen.window, xtmp, ytmp, @box_width,
                                  @box_height)
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Make the scrolling window
          @win = Curses::Window.new(@box_height, @box_width, ypos, xpos)

          # Is the scrolling window null?
          return nil if @win.nil?

          # Turn the keypad on for the window
          @win.keypad(true)

          # Create the scrollbar window.
          if splace == Slithernix::Cdk::RIGHT
            @scrollbar_win = @win.subwin(
              maxViewSize,
              1,
              self.SCREEN_YPOS(ypos),
              xpos + box_width - @border_size - 1,
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

          # create the list window
          @list_win = @win.subwin(
            maxViewSize,
            box_width - (2 * @border_size) - scroll_adjust,
            self.SCREEN_YPOS(ypos),
            self.SCREEN_XPOS(xpos) + (splace == Slithernix::Cdk::LEFT ? 1 : 0),
          )

          # Set the rest of the variables
          @screen = cdkscreen
          @parent = cdkscreen.window
          @shadow_win = nil
          @scrollbar_placement = splace
          @max_left_char = 0
          @left_char = 0
          @highlight = highlight
          # initExitType (scrollp);
          @accepts_focus = true
          @input_window = @win
          @shadow = shadow

          setPosition(0)

          # Create the scrolling list item list and needed variables.
          return nil if createItemList(numbers, list, list_size) <= 0

          # Do we need to create a shadow?
          if shadow
            @shadow_win = Curses::Window.new(
              @box_height,
              box_width,
              ypos + 1,
              xpos + 1,
            )
          end

          # Set up the key bindings.
          bindings.each do |from, to|
            # self.bind(:SCROLL, from, getc_lambda, to)
            bind(:Scroll, from, :getc, to)
          end

          cdkscreen.register(:Scroll, self)
        end

        def widget_type
          :Scroll
        end

        def position
          super(@win)
        end

        # Put the cursor on the currently-selected item's row.
        def fixCursorPosition
          @scrollbar_placement == LEFT ? 1 : 0
          self.SCREEN_YPOS(@current_item - @current_top)
          self.SCREEN_XPOS(0)

          # Another .move that breaks a bunch of stuff!, BIGLY!!!
          # @input_window.move(ypos, xpos)
          @input_window.refresh
        end

        # This actually does all the 'real' work of managing the scrolling list.
        def activate(actions)
          # Draw the scrolling list
          draw(@box)

          if actions.nil? || actions.empty?
            while true
              fixCursorPosition
              input = getch([])

              # Inject the character into the widget.
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

          # Set the exit type for the widget and return
          setExitType(0)
          -1
        end

        # This injects a single character into the widget.
        def inject(input)
          pp_return = 1
          ret = -1
          complete = false

          # Set the exit type for the widget.
          setExitType(0)

          # Draw the scrolling list
          drawList(@box)

          # Check if there is a pre-process function to be called.
          unless @pre_process_func.nil?
            pp_return = @pre_process_func.call(
              :Scroll,
              self,
              @pre_process_data,
              input,
            )
          end

          # Should we continue?
          if pp_return != 0
            # Check for a predefined key binding.
            if checkBind(:Scroll, input) == false
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
              when Slithernix::Cdk::KEY_ESC
                setExitType(input)
                complete = true
              when Curses::Error
                setExitType(input)
                complete = true
              when Slithernix::Cdk::REFRESH
                @screen.erase
                @screen.refresh
              when Slithernix::Cdk::KEY_TAB, Curses::KEY_ENTER, Slithernix::Cdk::KEY_RETURN
                setExitType(input)
                ret = @current_item
                complete = true
              end
            else
              # self.checkEarlyExit
              complete = true
            end

            if !complete && @post_process_func
              @post_process_func.call(:Scroll, self, @post_process_data, input)
            end
          end

          unless complete
            drawList(@box)
            setExitType(0)
          end

          fixCursorPosition
          @result_data = ret

          # return ret != -1
          ret
        end

        def getCurrentTop
          @current_top
        end

        def setCurrentTop(item)
          if item.negative?
            item = 0
          elsif item > @max_top_item
            item = @max_top_item
          end
          @current_top = item

          setPosition(item)
        end

        # This moves the scroll field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@win, @list_win, @shadow_win, @scrollbar_win]
          move_specific(xplace, yplace, relative, refresh_flag,
                        windows, [])
        end

        # This function draws the scrolling list widget.
        def draw(box)
          # Draw in the shadow if we need to.
          Slithernix::Cdk::Draw.drawShadow(@shadow_win) unless @shadow_win.nil?

          drawTitle(@win)

          # Draw in the scrolling list items.
          drawList(box)
        end

        def drawCurrent
          # Rehighlight the current menu item.
          screen_pos = @item_pos[@current_item] - @left_char
          highlight = has_focus ? @highlight : Curses::A_NORMAL

          Slithernix::Cdk::Draw.writeChtypeAttrib(
            @list_win,
            [screen_pos, 0].max,
            @current_high,
            @item[@current_item],
            highlight,
            Slithernix::Cdk::HORIZONTAL,
            screen_pos >= 0 ? 0 : (1 - screen_pos),
            @item_len[@current_item],
          )
        end

        def drawList(box)
          # If the list is empty, don't draw anything.
          if @list_size.positive?
            # Redraw the list
            (0...@view_size).each do |j|
              k = j + @current_top

              Slithernix::Cdk::Draw.writeBlanks(
                @list_win,
                0,
                j,
                Slithernix::Cdk::HORIZONTAL,
                0,
                @box_width - (2 * @border_size),
              )

              # Draw the elements in the scrolling list.
              next unless k < @list_size

              screen_pos = @item_pos[k] - @left_char
              ypos = j

              # Write in the correct line.
              Slithernix::Cdk::Draw.writeChtype(
                @list_win,
                screen_pos >= 0 ? screen_pos : 1,
                ypos,
                @item[k],
                Slithernix::Cdk::HORIZONTAL,
                screen_pos >= 0 ? 0 : (1 - screen_pos),
                @item_len[k],
              )
            end

            drawCurrent

            # Determine where the toggle is supposed to be.
            unless @scrollbar_win.nil?
              @toggle_pos = (@current_item * @step).floor

              # Make sure the toggle button doesn't go out of bounds.

              if @toggle_pos >= @scrollbar_win.maxy
                @toggle_pos = @scrollbar_win.maxy - 1
              end

              # Draw the scrollbar
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
          end

          # Box it if needed.
          Slithernix::Cdk::Draw.drawObjBox(@win, self) if box

          # Refresh the window
          @win.refresh
        end

        # This sets the background attribute of the widget.
        def setBKattr(attrib)
          @win.wbkgd(attrib)
          @list_win.wbkgd(attrib)
          @scrollbar_win&.wbkgd(attrib)
        end

        # This function destroys
        def destroy
          cleanTitle

          # Clean up the windows.
          Slithernix::Cdk.deleteCursesWindow(@scrollbar_win)
          Slithernix::Cdk.deleteCursesWindow(@shadow_win)
          Slithernix::Cdk.deleteCursesWindow(@list_win)
          Slithernix::Cdk.deleteCursesWindow(@win)

          # Clean the key bindings.
          cleanBindings(:Scroll)

          # Unregister this widget
          Slithernix::Cdk::Screen.unregister(:Scroll, self)
        end

        # This function erases the scrolling list from the screen.
        def erase
          Slithernix::Cdk.eraseCursesWindow(@win)
          Slithernix::Cdk.eraseCursesWindow(@shadow_win)
        end

        def allocListArrays(old_size, new_size)
          result = true
          new_list = Array.new(new_size)
          new_len = Array.new(new_size)
          new_pos = Array.new(new_size)

          (0...old_size).each do |n|
            new_list[n] = @item[n]
            new_len[n] = @item_len[n]
            new_pos[n] = @item_pos[n]
          end

          @item = new_list
          @item_len = new_len
          @item_pos = new_pos

          result
        end

        def allocListItem(which, _work, _used, number, value)
          value = format('%4d. %s', number, value) if number.positive?

          item_len = []
          item_pos = []
          @item[which] = Slithernix::Cdk.char2Chtype(value, item_len, item_pos)
          @item_len[which] = item_len[0]
          @item_pos[which] = item_pos[0]

          @item_pos[which] = Slithernix::Cdk.justifyString(@box_width,
                                                           @item_len[which], @item_pos[which])
          true
        end

        # This function creates the scrolling list information and sets up the
        # needed variables for the scrolling list to work correctly.
        def createItemList(numbers, list, list_size)
          status = 0
          if list_size.positive?
            widest_item = 0
            have = 0
            temp = String.new
            if allocListArrays(0, list_size)
              # Create the items in the scrolling list.
              status = 1
              (0...list_size).each do |x|
                number = numbers ? x + 1 : 0
                unless allocListItem(x, temp, have, number, list[x])
                  status = 0
                  break
                end

                widest_item = [@item_len[x], widest_item].max
              end

              if status
                updateViewWidth(widest_item)

                # Keep the boolean flag 'numbers'
                @numbers = numbers
              end
            end
          else
            status = 1 # null list is ok - for a while
          end

          status
        end

        # This sets certain attributes of the scrolling list.
        def set(list, list_size, numbers, highlight, box)
          setItems(list, list_size, numbers)
          setHighlight(highlight)
          setBox(box)
        end

        # This sets the scrolling list items
        def setItems(list, list_size, numbers)
          return if createItemList(numbers, list, list_size) <= 0

          # Clean up the display.
          (0...@view_size).each do |x|
            Slithernix::Cdk::Draw.writeBlanks(@win, 1, x,
                                              Slithernix::Cdk::HORIZONTAL, 0, @box_width - 2)
          end

          setViewSize(list_size)
          setPosition(0)
          @left_char = 0
        end

        def getItems(list)
          (0...@list_size).each do |x|
            list << Slithernix::Cdk.chtype2Char(@item[x])
          end

          @list_size
        end

        # This sets the highlight of the scrolling list.
        def setHighlight(highlight)
          @highlight = highlight
        end

        def getHighlight(_highlight)
          @highlight
        end

        # Resequence the numbers after an insertion/deletion.
        def resequence
          return unless @numbers

          (0...@list_size).each do |j|
            target = @item[j]

            source = format('%4d. %s', j + 1, '')

            k = 0
            while k < source.size
              # handle deletions that change the length of number
              if source[k] == '.' && target[k] != '.'
                source = source[0...k] + source[k + 1..]
              end

              target[k] &= Curses::A_ATTRIBUTES
              target[k] |= source[k].ord
              k += 1
            end
          end
        end

        def insertListItem(item)
          @item = @item[0..item] + @item[item..]
          @item_len = @item_len[0..item] + @item_len[item..]
          @item_pos = @item_pos[0..item] + @item_pos[item..]
          true
        end

        # This adds a single item to a scrolling list, at the end of the list.
        def addItem(item)
          item_number = @list_size
          widest_item = self.WidestItem
          temp = String.new
          have = 0

          if allocListArrays(
            @list_size,
            @list_size + 1
          ) &&
             allocListItem(
               item_number,
               temp,
               have,
               @numbers ? item_number + 1 : 0,
               item,
             )
            # Determine the size of the widest item.
            widest_item = [@item_len[item_number], widest_item].max

            updateViewWidth(widest_item)
            setViewSize(@list_size + 1)
          end
        end

        # This adds a single item to a scrolling list before the current item
        def insertItem(item)
          widest_item = self.WidestItem
          temp = String.new
          have = 0

          if allocListArrays(
            @list_size,
            @list_size + 1
          ) &&
             insertListItem(
               @current_item
             ) &&
             allocListItem(
               @current_item,
               temp,
               have,
               @numbers ? @current_item + 1 : 0,
               item
             )
            # Determine the size of the widest item.
            widest_item = [@item_len[@current_item], widest_item].max

            updateViewWidth(widest_item)
            setViewSize(@list_size + 1)
            resequence
          end
        end

        # This removes a single item from a scrolling list.
        def deleteItem(position)
          return unless position >= 0 && position < @list_size

          # Adjust the list
          @item = @item[0...position] + @item[position + 1..]
          @item_len = @item_len[0...position] + @item_len[position + 1..]
          @item_pos = @item_pos[0...position] + @item_pos[position + 1..]

          setViewSize(@list_size - 1)

          resequence if @list_size.positive?

          if @list_size < maxViewSize
            @win.erase # force the next redraw to be complete
          end

          # do this to update the view size, etc
          setPosition(@current_item)
        end

        def focus
          drawCurrent
          @list_win.refresh
        end

        def unfocus
          drawCurrent
          @list_win.refresh
        end

        def AvailableWidth
          @box_width - (2 * @border_size)
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
      end

      class BUTTON < Slithernix::Cdk::Widget
        def initialize(cdkscreen, xplace, yplace, text, callback, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          box_width = 0
          xpos = xplace
          ypos = yplace

          setBox(box)
          box_height = 1 + (2 * @border_size)

          # Translate the string to a chtype array.
          info_len = []
          info_pos = []
          @info = Slithernix::Cdk.char2Chtype(text, info_len, info_pos)
          @info_len = info_len[0]
          @info_pos = info_pos[0]
          box_width = [box_width, @info_len].max + (2 * @border_size)

          # Create the string alignments.
          @info_pos = Slithernix::Cdk.justifyString(box_width - (2 * @border_size),
                                                    @info_len, @info_pos)

          # Make sure we didn't extend beyond the dimensions of the window.
          box_width = parent_width if box_width > parent_width
          box_height = parent_height if box_height > parent_height

          # Rejustify the x and y positions if we need to.
          xtmp = [xpos]
          ytmp = [ypos]
          Slithernix::Cdk.alignxy(cdkscreen.window, xtmp, ytmp, box_width,
                                  box_height)
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
            @shadow_win = Curses::Window.new(box_height, box_width,
                                             ypos + 1, xpos + 1)
          end

          # Register this baby.
          cdkscreen.register(:BUTTON, self)
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
          setExitType(0)
          -1
        end

        # This sets multiple attributes of the widget.
        def set(mesg, box)
          setMessage(mesg)
          setBox(box)
        end

        # This sets the information within the button.
        def setMessage(info)
          info_len = []
          info_pos = []
          @info = Slithernix::Cdk.char2Chtype(info, info_len, info_pos)
          @info_len = info_len[0]
          @info_pos = Slithernix::Cdk.justifyString(@box_width - (2 * @border_size),
                                                    info_pos[0])

          # Redraw the button widget.
          erase
          draw(box)
        end

        def getMessage
          @info
        end

        # This sets the background attribute of the widget.
        def setBKattr(attrib)
          @win.wbkgd(attrib)
        end

        def drawText
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
          Slithernix::Cdk::Draw.drawShadow(@shadow_win) unless @shadow_win.nil?

          # Box the widget if asked.
          Slithernix::Cdk::Draw.drawObjBox(@win, self) if @box
          drawText
          @win.refresh
        end

        # This erases the button widget.
        def erase
          return unless validCDKObject

          Slithernix::Cdk.eraseCursesWindow(@win)
          Slithernix::Cdk.eraseCursesWindow(@shadow_win)
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
          Slithernix::Cdk.alignxy(@screen.window, xtmp, ytmp, @box_width,
                                  @box_height)
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Get the difference
          xdiff = current_x - xpos
          ydiff = current_y - ypos

          # Move the window to the new location.
          Slithernix::Cdk.moveCursesWindow(@win, -xdiff, -ydiff)
          Slithernix::Cdk.moveCursesWindow(@shadow_win, -xdiff, -ydiff)

          # Thouch the windows so they 'move'.
          Slithernix::Cdk::Screen.refreshCDKWindow(@screen.window)

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
                Slithernix::Cdk.Beep
              end
            elsif [Curses::KEY_DOWN, '2'].include?(key)
              if @win.begy + @win.maxy < @screen.window.maxy - 1
                move(0, 1, true, true)
              else
                Slithernix::Cdk.Beep
              end
            elsif [Curses::KEY_LEFT, '4'].include?(key)
              if @win.begx.positive?
                move(-1, 0, true, true)
              else
                Slithernix::Cdk.Beep
              end
            elsif [Curses::KEY_RIGHT, '6'].include?(key)
              if @win.begx + @win.maxx < @screen.window.maxx - 1
                move(1, 0, true, true)
              else
                Slithernix::Cdk.Beep
              end
            elsif key == '7'
              if @win.begy.positive? && @win.begx.positive?
                move(-1, -1, true, true)
              else
                Slithernix::Cdk.Beep
              end
            elsif key == '9'
              if @win.begx + @win.maxx < @screen.window.maxx - 1 &&
                 @win.begy.positive?
                move(1, -1, true, true)
              else
                Slithernix::Cdk.Beep
              end
            elsif key == '1'
              if @win.begx.positive? &&
                 @win.begx + @win.maxx < @screen.window.maxx - 1
                move(-1, 1, true, true)
              else
                Slithernix::Cdk.Beep
              end
            elsif key == '3'
              if @win.begx + @win.maxx < @screen.window.maxx - 1 &&
                 @win.begy + @win.maxy < @screen.window.maxy - 1
                move(1, 1, true, true)
              else
                Slithernix::Cdk.Beep
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
              Slithernix::Cdk.Beep
            end
          end
        end

        # This destroys the button widget pointer.
        def destroy
          Slithernix::Cdk.deleteCursesWindow(@shadow_win)
          Slithernix::Cdk.deleteCursesWindow(@win)

          cleanBindings(:BUTTON)

          Slithernix::Cdk::Screen.unregister(:BUTTON, self)
        end

        # This injects a single character into the widget.
        def inject(input)
          ret = -1
          complete = false

          setExitType(0)

          # Check a predefined binding.
          if checkBind(:BUTTON, input)
            complete = true
          else
            case input
            when Slithernix::Cdk::KEY_ESC
              setExitType(input)
              complete = true
            when Curses::Error
              setExitType(input)
              complete = true
            when ' ', Slithernix::Cdk::KEY_RETURN, Curses::KEY_ENTER
              @callback&.call(self)
              setExitType(Curses::KEY_ENTER)
              ret = 0
              complete = true
            when Slithernix::Cdk::REFRESH
              @screen.erase
              @screen.refresh
            else
              Slithernix::Cdk.Beep
            end
          end

          setExitType(0) unless complete

          @result_data = ret
          ret
        end

        def focus
          drawText
          @win.refresh
        end

        def unfocus
          drawText
          @win.refresh
        end
      end
    end
  end
end
