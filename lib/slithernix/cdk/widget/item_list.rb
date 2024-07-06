require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class ItemList < Slithernix::Cdk::Widget
        def initialize(cdkscreen, xplace, yplace, title, label, item, count,
                       default_item, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          field_width = 0

          unless createList(item, count)
            destroy
            return nil
          end

          setBox(box)
          box_height = (@border_size * 2) + 1

          # Set some basic values of the item list
          @label = ''
          @label_len = 0
          @label_win = nil

          # Translate the label string to a chtype array
          if label&.size&.positive?
            label_len = []
            @label = Slithernix::Cdk.char2Chtype(label, label_len, [])
            @label_len = label_len[0]
          end

          # Set the box width. Allow an extra char in field width for cursor
          field_width = maximumFieldWidth + 1
          box_width = field_width + @label_len + (2 * @border_size)
          box_width = setTitle(title, box_width)
          box_height += @title_lines

          # Make sure we didn't extend beyond the dimensions of the window
          @box_width = [box_width, parent_width].min
          @box_height = [box_height, parent_height].min
          updateFieldWidth

          # Rejustify the x and y positions if we need to.
          xtmp = [xplace]
          ytmp = [yplace]
          Slithernix::Cdk.alignxy(cdkscreen.window, xtmp, ytmp, box_width,
                                  box_height)
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Make the window.
          @win = Curses::Window.new(box_height, box_width, ypos, xpos)
          if @win.nil?
            destroy
            return nil
          end

          # Make the label window if there was a label.
          if @label.size.positive?
            @label_win = @win.subwin(1, @label_len,
                                     ypos + @border_size + @title_lines,
                                     xpos + @border_size)

            if @label_win.nil?
              destroy
              return nil
            end
          end

          @win.keypad(true)

          # Make the field window.
          unless createFieldWin(
            ypos + @border_size + @title_lines,
            xpos + @label_len + @border_size
          )
            destroy
            return nil
          end

          # Set up the rest of the structure
          @screen = cdkscreen
          @parent = cdkscreen.window
          @shadow_win = nil
          @accepts_focus = true
          @shadow = shadow

          # Set the default item.
          if default_item >= 0 && default_item < @list_size
            @current_item = default_item
            @default_item = default_item
          else
            @current_item = 0
            @default_item = 0
          end

          # Do we want a shadow?
          if shadow
            @shadow_win = Curses::Window.new(box_height, box_width,
                                             ypos + 1, xpos + 1)
            if @shadow_win.nil?
              destroy
              return nil
            end
          end

          # Register this baby.
          cdkscreen.register(:ItemList, self)
        end

        # This allows the user to play with the widget.
        def activate(actions)
          ret = -1

          # Draw the widget.
          draw(@box)
          drawField(true)

          if actions.nil? || actions.size.zero?
            input = 0

            loop do
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

          # Set the exit type and exit.
          setExitType(0)
          ret
        end

        # This injects a single character into the widget.
        def inject(input)
          pp_return = 1
          ret = -1
          complete = false

          # Set the exit type.
          setExitType(0)

          # Draw the widget field
          drawField(true)

          # Check if there is a pre-process function to be called.
          unless @pre_process_func.nil?
            pp_return = @pre_process_func.call(:ItemList, self,
                                               @pre_process_data, input)
          end

          # Should we continue?
          if pp_return != 0
            # Check a predefined binding.
            if checkBind(:ItemList, input)
              complete = true
            else
              case input
              when Curses::KEY_UP, Curses::KEY_RIGHT, ' ', '+', 'n'
                if @current_item < @list_size - 1
                  @current_item += 1
                else
                  @current_item = 0
                end
              when Curses::KEY_DOWN, Curses::KEY_LEFT, '-', 'p'
                if @current_item.positive?
                  @current_item -= 1
                else
                  @current_item = @list_size - 1
                end
              when 'd', 'D'
                @current_item = @default_item
              when '0'
                @current_item = 0
              when '$'
                @current_item = @list_size - 1
              when Slithernix::Cdk::KEY_ESC
                setExitType(input)
                complete = true
              when Curses::Error
                setExitType(input)
                complete = true
              when Slithernix::Cdk::KEY_TAB, Slithernix::Cdk::KEY_RETURN, Curses::KEY_ENTER
                setExitType(input)
                ret = @current_item
                complete = true
              when Slithernix::Cdk::REFRESH
                @screen.erase
                @screen.refresh
              else
                Slithernix::Cdk.Beep
              end
            end

            # Should we call a post-process?
            if !complete and @post_process_func
              @post_process_func.call(:ItemList, self, @post_process_data,
                                      input)
            end
          end

          unless complete
            drawField(true)
            setExitType(0)
          end

          @result_data = ret
          ret
        end

        # This moves the itemlist field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@win, @field_win, @label_win, @shadow_win]
          move_specific(xplace, yplace, relative, refresh_flag,
                        windows, [])
        end

        # This draws the widget on the screen.
        def draw(box)
          # Did we ask for a shadow?
          Slithernix::Cdk::Draw.drawShadow(@shadow_win) unless @shadow_win.nil?

          drawTitle(@win)

          # Draw in the label to the widget.
          unless @label_win.nil?
            Slithernix::Cdk::Draw.writeChtype(@label_win, 0, 0, @label, Slithernix::Cdk::HORIZONTAL,
                                              0, @label.size)
          end

          # Box the widget if asked.
          Slithernix::Cdk::Draw.drawObjBox(@win, self) if box

          @win.refresh

          # Draw in the field.
          drawField(false)
        end

        # This sets the background attribute of the widget
        def setBKattr(attrib)
          @win.wbkgd(attrib)
          @field_win.wbkgd(attrib)
          @label_win.wbkgd(attrib) unless @label_win.nil?
        end

        # This function draws the contents of the field.
        def drawField(highlight)
          # Declare local vars.
          current_item = @current_item

          # Determine how much we have to draw.
          len = [@item_len[current_item], @field_width].min

          # Erase the field window.
          @field_win.erase

          # Draw in the current item in the field.
          (0...len).each do |x|
            c = @item[current_item][x]

            c = c.ord | Curses::A_REVERSE if highlight

            @field_win.mvwaddch(0, x + @item_pos[current_item], c)
          end

          # Redraw the field window.
          @field_win.refresh
        end

        # This function removes the widget from the screen.
        def erase
          return unless validCDKObject

          Slithernix::Cdk.eraseCursesWindow(@field_win)
          Slithernix::Cdk.eraseCursesWindow(@label_win)
          Slithernix::Cdk.eraseCursesWindow(@win)
          Slithernix::Cdk.eraseCursesWindow(@shadow_win)
        end

        def destroyInfo
          @list_size = 0
          @item = ''
        end

        # This function destroys the widget and all the memory it used.
        def destroy
          cleanTitle
          destroyInfo

          # Delete the windows
          Slithernix::Cdk.deleteCursesWindow(@field_win)
          Slithernix::Cdk.deleteCursesWindow(@label_win)
          Slithernix::Cdk.deleteCursesWindow(@shadow_win)
          Slithernix::Cdk.deleteCursesWindow(@win)

          # Clean the key bindings.
          cleanBindings(:ItemList)

          Slithernix::Cdk::Screen.unregister(:ItemList, self)
        end

        # This sets multiple attributes of the widget.
        def set(list, count, current, box)
          setValues(list, count, current)
          setBox(box)
        end

        # This function sets the contents of the list
        def setValues(item, count, default_item)
          return unless createList(item, count)

          old_width = @field_width

          # Set the default item.
          if default_item >= 0 && default_item < @list_size
            @current_item = default_item
            @default_item = default_item
          end

          # This will not resize the outer windows but can still make a usable
          # field width if the title made the outer window wide enough
          updateFieldWidth
          if @field_width > old_width
            createFieldWin(@field_win.begy, @field_win.begx)
          end

          # Draw the field.
          erase
          draw(@box)
        end

        def getValues(size)
          size << @list_size
          @item
        end

        # This sets the default/current item of the itemlist
        def setCurrentItem(current_item)
          # Set the default item.
          return unless current_item >= 0 && current_item < @list_size

          @current_item = current_item
        end

        def getCurrentItem
          @current_item
        end

        # This sets the default item in the list.
        def setDefaultItem(default_item)
          # Make sure the item is in the correct range.
          @default_item = if default_item.negative?
                            0
                          elsif default_item >= @list_size
                            @list_size - 1
                          else
                            default_item
                          end
        end

        def getDefaultItem
          @default_item
        end

        def focus
          drawField(true)
        end

        def unfocus
          drawField(false)
        end

        def createList(item, count)
          status = false
          new_items = []
          new_pos = []
          new_len = []
          if count >= 0
            field_width = 0

            # Go through the list and determine the widest item.
            status = true
            (0...count).each do |x|
              # Copy the item to the list.
              lentmp = []
              postmp = []
              new_items << Slithernix::Cdk.char2Chtype(item[x], lentmp, postmp)
              new_len << lentmp[0]
              new_pos << postmp[0]
              if (new_items[0]).zero?
                status = false
                break
              end
              field_width = [field_width, new_len[x]].max
            end

            # Now we need to justify the strings.
            (0...count).each do |x|
              new_pos[x] = Slithernix::Cdk.justifyString(field_width + 1,
                                                         new_len[x], new_pos[x])
            end

            if status
              destroyInfo

              # Copy in the new information
              @list_size = count
              @item = new_items
              @item_pos = new_pos
              @item_len = new_len
            end
          else
            destroyInfo
            status = true
          end

          status
        end

        # Go through the list and determine the widest item.
        def maximumFieldWidth
          max_width = -2**30

          (0...@list_size).each do |x|
            max_width = [max_width, @item_len[x]].max
          end
          [max_width, 0].max
        end

        def updateFieldWidth
          want = maximumFieldWidth + 1
          have = @box_width - @label_len - (2 * @border_size)
          @field_width = [want, have].min
        end

        # Make the field window.
        def createFieldWin(ypos, xpos)
          @field_win = @win.subwin(1, @field_width, ypos, xpos)
          unless @field_win.nil?
            @field_win.keypad(true)
            @input_window = @field_win
            return true
          end
          false
        end

        def position
          super(@win)
        end
      end
    end
  end
end
