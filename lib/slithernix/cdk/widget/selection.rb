require_relative 'scroller'

module Slithernix
  module Cdk
    class Widget
      class Selection < Slithernix::Cdk::Widget::Scroller
        attr_reader :selections

        def initialize(cdkscreen, xplace, yplace, splace, height, width, title, list, list_size, choices, choice_count, highlight, box, shadow)
          super()
          widest_item = -1
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          box_width = width
          bindings = {
            'g' => Curses::KEY_HOME,
            '1' => Curses::KEY_HOME,
            'G' => Curses::KEY_END,
            '<' => Curses::KEY_HOME,
            '>' => Curses::KEY_END,
          }

          bindings[Slithernix::Cdk::BACKCHAR] = Curses::KEY_PPAGE,
          bindings[Slithernix::Cdk::FORCHAR]  = Curses::KEY_NPAGE,

          if choice_count <= 0
            self.destroy
            return nil
          end

          @choice = []
          @choicelen = []

          self.setBox(box)

          # If the height is a negative value, the height will be ROWS-height,
          # otherwise the height will be the given height.
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

          box_width = self.setTitle(title, box_width)

          # Set the box height.
          if @title_lines > box_height
            box_height = @title_lines = [list_size, 8].min, + 2 * border_size
          end

          @maxchoicelen = 0

          # Adjust the box width if there is a scroll bar.
          if splace == Slithernix::Cdk::LEFT || splace == Slithernix::Cdk::RIGHT
            box_width += 1
            @scrollbar = true
          else
            @scrollbar = false
          end

          # Make sure we didn't extend beyond the dimensions of the window.
          @box_width = [box_width, parent_width].min
          @box_height = [box_height, parent_height].min

          self.setViewSize(list_size)

          # Rejustify the x and y positions if we need to.
          xtmp = [xplace]
          ytmp = [yplace]
          Slithernix::Cdk.alignxy(cdkscreen.window, xtmp, ytmp, @box_width, @box_height)
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Make the selection window.
          @win = Curses::Window.new(@box_height, @box_width, ypos, xpos)

          # Is the window nil?
          if @win.nil?
            self.destroy
            return nil
          end

          # Turn the keypad on for this window.
          @win.keypad(true)

          # Create the scrollbar window.
          if splace == Slithernix::Cdk::RIGHT
            @scrollbar_win = @win.subwin(self.maxViewSize, 1,
                self.SCREEN_YPOS(ypos), xpos + @box_width - @border_size - 1)
          elsif splace == Slithernix::Cdk::LEFT
            @scrollbar_win = @win.subwin(self.maxViewSize, 1,
                self.SCREEN_YPOS(ypos), self.SCREEN_XPOS(ypos))
          else
            @scrollbar_win = nil
          end

          # Set the rest of the variables
          @screen = cdkscreen
          @parent = cdkscreen.window
          @scrollbar_placement = splace
          @max_left_char = 0
          @left_char = 0
          @highlight = highlight
          @choice_count = choice_count
          @accepts_focus = true
          @input_window = @win
          @shadow = shadow

          self.setCurrentItem(0)

          # Each choice has to be converted from string to chtype array
          (0...choice_count).each do |j|
            choicelen = []
            @choice << Slithernix::Cdk.char2Chtype(choices[j], choicelen, [])
            @choicelen << choicelen[0]
            @maxchoicelen = [@maxchoicelen, choicelen[0]].max
          end

          # Each item in the needs to be converted to chtype array
          widest_item = self.createList(list, list_size)
          if widest_item > 0
            self.updateViewWidth(widest_item)
          elsif list_size > 0
            self.destroy
            return nil
          end

          # Do we need to create a shadow.
          if shadow
            @shadow_win = Curses::Window.new(box_height, box_width,
                ypos + 1, xpos + 1)
          end

          # Setup the key bindings
          bindings.each do |from, to|
            self.bind(:Selection, from, :getc, to)
          end

          # Register this baby.
          cdkscreen.register(:Selection, self)
        end

        # Put the cursor on the currently-selected item.
        def fixCursorPosition
          scrollbar_adj = if @scrollbar_placement == Slithernix::Cdk::LEFT
                          then 1
                          else 0
                          end
          ypos = self.SCREEN_YPOS(@current_item - @current_top)
          xpos = self.SCREEN_XPOS(0) + scrollbar_adj

          # Don't know why this was set up here, since this moves the window -- snake 2024
          #@input_window.move(ypos, xpos)
          @input_window.refresh
        end

        # This actually manages the selection widget
        def activate(actions)
          # Draw the selection list
          self.draw(@box)

          if actions.nil? || actions.size == 0
            while true
              self.fixCursorPosition
              input = self.getch([])

              # Inject the character into the widget.
              ret = self.inject(input)
              if @exit_type != :EARLY_EXIT
                return ret
              end
            end
          else
            # Inject each character one at a time.
            actions.each do |action|
              ret = self.inject(action)
              if @exit_type != :EARLY_EXIT
                return ret
              end
            end
          end

          # Set the exit type and return.
          self.setExitType(0)
          return 0
        end

        # This injects a single characer into the widget.
        def inject(input)
          pp_return = 1
          ret = -1
          complete = false

          # Set the exit type
          self.setExitType(0)

          # Draw the widget list.
          self.drawList(@box)

          # Check if there is a pre-process function to be called.
          unless @pre_process_func.nil?
            pp_return = @pre_process_func.call(:Selection, self,
                                               @pre_process_data, input)
          end

          # Should we continue?
          if pp_return != 0
            # Check for a predefined binding.
            if self.checkBind(:Selection, input)
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
                if @mode[@current_item] == 0
                  if @selections[@current_item] == @choice_count - 1
                    @selections[@current_item] = 0
                  else
                    @selections[@current_item] += 1
                  end
                else
                  Slithernix::Cdk.Beep
                end
              when Slithernix::Cdk::KEY_ESC
                self.setExitType(input)
                complete = true
              when Curses::Error
                self.setExitType(input)
                complete = true
              when Curses::KEY_ENTER, Slithernix::Cdk::KEY_TAB, Slithernix::Cdk::KEY_RETURN
                self.setExitType(input)
                ret = 1
                complete = true
              when Slithernix::Cdk::REFRESH
                @screen.erase
                @screen.refresh
              end
            end

            # Should we call a post-process?
            if !complete && !(@post_process_func.nil?)
              @post_process_func.call(:Selection, self, @post_process_data, input)
            end
          end

          unless complete
            self.drawList(@box)
            self.setExitType(0)
          end

          @result_data = ret
          self.fixCursorPosition
          return ret
        end

        # This moves the selection field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@win, @scrollbar_win, @shadow_win]
          self.move_specific(xplace, yplace, relative, refresh_flag,
              windows, [])
        end

        # This function draws the selection list.
        def draw(box)
          # Draw in the shadow if we need to.
          unless @shadow_win.nil?
            Slithernix::Cdk::Draw.drawShadow(@shadow_win)
          end

          self.drawTitle(@win)

          # Redraw the list
          self.drawList(box)
        end

        # This function draws the selection list window.
        def drawList(box)
          scrollbar_adj = @scrollbar_placement == LEFT ? 1 : 0
          screen_pos = 0
          sel_item = -1

          # If there is to be a highlight, assign it now
          if @has_focus
            sel_item = @current_item
          end

          # draw the list...
          j = 0
          while j < @view_size && (j + @current_top) < @list_size
            k = j + @current_top
            if k < @list_size
              screen_pos = self.SCREENPOS(k, scrollbar_adj)
              ypos = self.SCREEN_YPOS(j)
              xpos = self.SCREEN_XPOS(0)

              # Draw the empty line.
              Slithernix::Cdk::Draw.writeBlanks(
                @win,
                xpos,
                ypos,
                Slithernix::Cdk::HORIZONTAL,
                0,
                @win.maxx,
              )

              # Draw the selection item.
              Slithernix::Cdk::Draw.writeChtypeAttrib(
                @win,
                screen_pos >= 0 ? screen_pos : 1,
                ypos,
                @item[k],
                k == sel_item ? @highlight : Curses::A_NORMAL,
                Slithernix::Cdk::HORIZONTAL,
                screen_pos >= 0 ? 0 : 1 - screen_pos,
                @item_len[k],
              )

              # Draw the choice value
              Slithernix::Cdk::Draw.writeChtype(
                @win,
                xpos + scrollbar_adj,
                ypos,
                @choice[@selections[k]],
                Slithernix::Cdk::HORIZONTAL,
                0,
                @choicelen[@selections[k]],
              )
            end

            j += 1
          end

          # Determine where the toggle is supposed to be.
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

          # Box it if needed
          if @box
            Slithernix::Cdk::Draw.drawObjBox(@win, self)
          end

          self.fixCursorPosition
        end

        # This sets the background attribute of the widget.
        def setBKattr(attrib)
          @win.wbkgd(attrib)
          unless @scrollbar_win.nil?
            @scrollbar_win.wbkgd(attrib)
          end
        end

        def destroyInfo
          @item = []
        end

        # This function destroys the selection list.
        def destroy
          self.cleanTitle
          self.destroyInfo

          # Clean up the windows.
          Slithernix::Cdk.deleteCursesWindow(@scrollbar_win)
          Slithernix::Cdk.deleteCursesWindow(@shadow_win)
          Slithernix::Cdk.deleteCursesWindow(@win)

          # Clean up the key bindings
          self.cleanBindings(:Selection)

          # Unregister this widget.
          Slithernix::Cdk::Screen.unregister(:Selection, self)
        end

        # This function erases the selection list from the screen.
        def erase
          if self.validCDKObject
            Slithernix::Cdk.eraseCursesWindow(@win)
            Slithernix::Cdk.eraseCursesWindow(@shadow_win)
          end
        end

        # This function sets a couple of the selection list attributes
        def set(highlight, choices, box)
          self.setChoices(choices)
          self.setHighlight(highlight)
          self.setBox(box)
        end

        # This sets the selection list items.
        def setItems(list, list_size)
          widest_item = self.createList(list, list_size)
          if widest_item <= 0
            return
          end

          # Clean up the display
          (0...@view_size).each do |j|
            Slithernix::Cdk::Draw.writeBlanks(
              @win,
              self.SCREEN_XPOS(0),
              self.SCREEN_YPOS(j),
              Slithernix::Cdk::HORIZONTAL,
              0,
              @win.maxx,
            )
          end

          self.setViewSize(list_size)
          self.setCurrentItem(0)

          self.updateViewWidth(widest_item)
        end

        def getItems(list)
          @item.each do |item|
            list << Slithernix::Cdk.chtype2Char(item)
          end
          return @list_size
        end

        def setSelectionTitle(title)
          # Make sure the title isn't nil
          if title.nil?
            return
          end

          self.setTitle(title, -(@box_width + 1))

          self.setViewSize(@list_size)
        end

        def getTitle
          return Slithernix::Cdk.chtype2Char(@title)
        end

        # This sets the highlight bar.
        def setHighlight(highlight)
          @highlight = highlight
        end

        def getHighlight
          @highlight
        end

        # This sets the default choices for the selection list.
        def setChoices(choices)
          # Set the choice values in the selection list.
          (0...@list_size).each do |j|
            if choices[j] < 0
              @selections[j] = 0
            elsif choices[j] > @choice_count
              @selections[j] = @choice_count - 1
            else
              @selections[j] = choices[j]
            end
          end
        end

        def getChoices
          @selections
        end

        # This sets a single item's choice value.
        def setChoice(index, choice)
          correct_choice = choice
          correct_index = index

          # Verify that the choice value is in range.
          if choice < 0
            correct_choice = 0
          elsif choice > @choice_count
            correct_choice = @choice_count - 1
          end

          # make sure the index isn't out of range.
          if index < 0
            correct_index = 0
          elsif index > @list_size
            correct_index = @list_size - 1
          end

          # Set the choice value.
          @selections[correct_index] = correct_choice
        end

        def getChoice(index)
          # Make sure the index isn't out of range.
          if index < 0
            return @selections[0]
          elsif index > list_size
            return @selections[@list_size - 1]
          else
            return @selections[index]
          end
        end

        # This sets the modes of the items in the selection list. Currently
        # there are only two: editable=0 and read-only=1
        def setModes(modes)
          # set the modes
          (0...@list_size).each do |j|
            @mode[j] = modes[j]
          end
        end

        def getModes
          return @mode
        end

        # This sets a single mode of an item in the selection list.
        def setMode(index, mode)
          # Make sure the index isn't out of range.
          if index < 0
            @mode[0] = mode
          elsif index > @list_size
            @mode[@list_size - 1] = mode
          else
            @mode[index] = mode
          end
        end

        def getMode(index)
          # Make sure the index isn't out of range
          if index < 0
            return @mode[0]
          elsif index > list_size
            return @mode[@list_size - 1]
          else
            return @mode[index]
          end
        end

        def getCurrent
          return @current_item
        end

        # methods for generic type methods
        def focus
          self.drawList(@box)
        end

        def unfocus
          self.drawList(@box)
        end

        def createList(list, list_size)
          status = 0
          widest_item = 0

          if list_size >= 0
            new_list = []
            new_len = []
            new_pos = []

            box_width = self.AvailableWidth
            adjust = @maxchoicelen + @border_size

            status = 1
            (0...list_size).each do |j|
              lentmp = []
              postmp = []
              new_list << Slithernix::Cdk.char2Chtype(list[j], lentmp, postmp)
              new_len << lentmp[0]
              new_pos << postmp[0]
              #if new_list[j].size == 0
              if new_list[j].nil?
                status = 0
                break
              end
              new_pos[j] = Slithernix::Cdk.justifyString(
                box_width,
                new_len[j],
                new_pos[j],
              ) + adjust

              widest_item = [widest_item, new_len[j]].max
            end

            if status
              self.destroyInfo

              @item = new_list
              @item_pos = new_pos
              @item_len = new_len
              @selections = [0] * list_size
              @mode = [0] * list_size
            end
          else
            self.destroyInfo
          end

          return (status ? widest_item : 0)
        end

        # Determine how many characters we can shift to the right
        # before all the items have been scrolled off the screen.
        def AvailableWidth
          @box_width - 2 * @border_size - @maxchoicelen
        end

        def updateViewWidth(widest)
          @max_left_char = @box_width > widest ? 0 : widest - self.AvailableWidth
        end

        def WidestItem
          @max_left_char + self.AvailableWidth
        end

        def SCREENPOS(n, scrollbar_adj)
          @item_pos[n] - @left_char + scrollbar_adj
        end

        def position
          super(@win)
        end
      end
    end
  end
end
