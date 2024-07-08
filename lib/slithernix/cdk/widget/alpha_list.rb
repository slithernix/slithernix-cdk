# frozen_string_literal: true

require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class AlphaList < Slithernix::Cdk::Widget
        attr_reader :scroll_field, :entry_field, :list

        def initialize(cdkscreen, xplace, yplace, height, width, title, label,
                       list, list_size, filler_char, highlight, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          label_len = 0
          bindings = {
            Slithernix::Cdk::BACKCHAR => Curses::KEY_PPAGE,
            Slithernix::Cdk::FORCHAR => Curses::KEY_NPAGE
          }

          unless createList(list, list_size)
            destroy
            return nil
          end

          set_box(box)

          # If the height is a negative value, the height will be ROWS-height,
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
            0,
          )

          # Translate the label string to a chtype array
          if label&.size&.positive?
            lentmp = []
            Slithernix::Cdk.char2Chtype(label, lentmp, [])
            label_len = lentmp[0]
          end

          # Rejustify the x and y positions if we need to.
          xtmp = [xplace]
          ytmp = [yplace]
          Slithernix::Cdk.alignxy(
            cdkscreen.window,
            xtmp,
            ytmp,
            box_width,
            box_height,
          )
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Make the file selector window.
          @win = Curses::Window.new(box_height, box_width, ypos, xpos)

          if @win.nil?
            destroy
            return nil
          end
          @win.keypad(true)

          # Set some variables.
          @screen = cdkscreen
          @parent = cdkscreen.window
          @highlight = highlight
          @filler_char = filler_char
          @box_height = box_height
          @box_width = box_width
          @shadow = shadow
          @shadow_win = nil

          # Do we want a shadow?
          if shadow
            @shadow_win = Curses::Window.new(
              box_height,
              box_width,
              ypos + 1,
              xpos + 1,
            )
          end

          # Create the entry field.
          temp_width = if Slithernix::Cdk::Widget::AlphaList.isFullWidth(width)
                       then Slithernix::Cdk::FULL
                       else
                         box_width - 2 - label_len
                       end

          @entry_field = Slithernix::Cdk::Widget::Entry.new(
            cdkscreen,
            @win.begx,
            @win.begy,
            title,
            label,
            Curses::A_NORMAL,
            filler_char,
            :MIXED,
            temp_width,
            0,
            512,
            box,
            false,
          )

          if @entry_field.nil?
            destroy
            return nil
          end
          @entry_field.set_lower_left_corner_char(Slithernix::Cdk::ACS_LTEE)
          @entry_field.set_lower_right_corner_char(Slithernix::Cdk::ACS_RTEE)

          # Callback functions
          adjust_alphalist_cb = lambda do |_widget_type, _widget, alphalist, key|
            scrollp = alphalist.scroll_field
            entry = alphalist.entry_field

            if scrollp.list_size.positive?
              # Adjust the scrolling list.
              alphalist.injectMyScroller(key)

              # Set the value in the entry field.
              current = Slithernix::Cdk.chtype2Char(scrollp.item[scrollp.current_item])
              entry.setValue(current)
              entry.draw(entry.box)
              return true
            end
            Slithernix::Cdk.Beep
            false
          end

          complete_word_cb = lambda do |_widget_type, _widget, alphalist, _key|
            entry = alphalist.entry_field
            scrollp = nil
            alt_words = []

            if entry.info.empty?
              Slithernix::Cdk.Beep
              return true
            end

            # Look for a unique word match.
            index = Slithernix::Cdk.searchList(
              alphalist.list,
              alphalist.list.size,
              entry.info,
            )

            # if the index is less than zero, return we didn't find a match
            if index.negative?
              Slithernix::Cdk.Beep
              return true
            end

            # Did we find the last word in the list?
            if index == alphalist.list.size - 1
              entry.setValue(alphalist.list[index])
              entry.draw(entry.box)
              return true
            end

            # Ok, we found a match, is the next item similar?
            len = [entry.info.size, alphalist.list[index + 1].size].min
            ret = alphalist.list[index + 1][0...len] <=> entry.info
            if ret.zero?
              current_index = index

              # Start looking for alternate words
              # FIXME(original): bsearch would be more suitable.
              while current_index < alphalist.list.size &&
                    (alphalist.list[current_index][0...len] <=> entry.info).zero?
                alt_words << alphalist.list[current_index]
                current_index += 1
              end

              # Determine the height of the scrolling list.
              height = alt_words.size < 8 ? alt_words.size + 3 : 11

              # Create a scrolling list of close matches.
              scrollp = Slithernix::Cdk::Widget::Scroll.new(
                entry.screen,
                Slithernix::Cdk::CENTER,
                Slithernix::Cdk::CENTER,
                Slithernix::Cdk::RIGHT,
                height,
                -30,
                '<C></B/5>Possible Matches.',
                alt_words,
                alt_words.size,
                true,
                Curses::A_REVERSE,
                true,
                false,
              )

              # Allow them to select a close match.
              match = scrollp.activate([])
              selected = scrollp.current_item

              # Check how they exited the list.
              if scrollp.exit_type == :ESCAPE_HIT
                # Destroy the scrolling list.
                scrollp.destroy

                # Beep at the user.
                Slithernix::Cdk.Beep

                # Redraw the alphalist and return.
                alphalist.draw(alphalist.box)
                return true
              end

              # Destroy the scrolling list.
              scrollp.destroy

              # Set the entry field to the selected value.
              entry.set(alt_words[match], entry.min, entry.max, entry.box)

              # Move the highlight bar down to the selected value.
              (0...selected).each do |_x|
                alphalist.injectMyScroller(Curses::KEY_DOWN)
              end

              # Redraw the alphalist.
              alphalist.draw(alphalist.box)
            else
              # Set the entry field with the found item.
              entry.set(alphalist.list[index], entry.min, entry.max, entry.box)
              entry.draw(entry.box)
            end
            true
          end

          pre_process_entry_field = lambda do |_widget_type, _widget, alphalist, input|
            scrollp = alphalist.scroll_field
            entry = alphalist.entry_field
            entry.info.size
            result = 1
            empty = false

            if alphalist.does_bind_exist?(:AlphaList, input)
              result = 1 # Don't try to use this key in editing
            elsif (Slithernix::Cdk.isChar(input) &&
                input.chr.match(/^[[:alnum:][:punct:]]$/)) ||
                  [Curses::KEY_BACKSPACE, Curses::KEY_DC].include?(input)
              index = 0
              curr_pos = entry.screen_col + entry.left_char
              pattern = entry.info.clone
              if [Curses::KEY_BACKSPACE, Curses::KEY_DC].include?(input)
                curr_pos -= 1 if input == Curses::KEY_BACKSPACE
                pattern.slice!(curr_pos) if curr_pos >= 0
              else
                front = (pattern[0...curr_pos] or '')
                back = (pattern[curr_pos..] or '')
                pattern = front + input.chr + back
              end

              if pattern.empty?
                empty = true
              elsif (index = Slithernix::Cdk.searchList(alphalist.list,
                                                        alphalist.list.size, pattern)) >= 0
                # XXX: original uses n scroll downs/ups for <10 positions change
                scrollp.setPosition(index)
                alphalist.drawMyScroller
              else
                Slithernix::Cdk.Beep
                result = 0
              end
            end

            if empty
              scrollp.setPosition(0)
              alphalist.drawMyScroller
            end

            result
          end

          # Set the key bindings for the entry field.
          @entry_field.bind(
            :Entry,
            Curses::KEY_UP,
            adjust_alphalist_cb,
            self,
          )

          @entry_field.bind(
            :Entry,
            Curses::KEY_DOWN,
            adjust_alphalist_cb,
            self,
          )

          @entry_field.bind(
            :Entry,
            Curses::KEY_NPAGE,
            adjust_alphalist_cb,
            self,
          )

          @entry_field.bind(
            :Entry,
            Curses::KEY_PPAGE,
            adjust_alphalist_cb,
            self,
          )

          @entry_field.bind(
            :Entry,
            Slithernix::Cdk::KEY_TAB,
            complete_word_cb,
            self,
          )

          # Set up the post-process function for the entry field.
          @entry_field.set_pre_process(pre_process_entry_field, self)

          # Create the scrolling list.  It overlaps the entry field by one line if
          # we are using box-borders.
          temp_height = @entry_field.win.maxy - @border_size
          temp_width = if Slithernix::Cdk::Widget::AlphaList.isFullWidth(width)
                       then Slithernix::Cdk::FULL
                       else
                         box_width - 1
                       end

          @scroll_field = Slithernix::Cdk::Widget::Scroll.new(
            cdkscreen,
            @win.begx,
            @entry_field.win.begy + temp_height,
            Slithernix::Cdk::RIGHT,
            box_height - temp_height,
            temp_width,
            '',
            list,
            list_size,
            false,
            Curses::A_REVERSE,
            box,
            false,
          )

          @scroll_field.set_upper_left_corner_char(Slithernix::Cdk::ACS_LTEE)
          @scroll_field.set_upper_right_corner_char(Slithernix::Cdk::ACS_RTEE)

          # Setup the key bindings.
          bindings.each do |from, to|
            bind(:AlphaList, from, :getc, to)
          end

          cdkscreen.register(:AlphaList, self)
        end

        # This erases the alphalist from the screen.
        def erase
          return unless is_valid_widget?

          @scroll_field.erase
          @entry_field.erase

          Slithernix::Cdk.eraseCursesWindow(@shadow_win)
          Slithernix::Cdk.eraseCursesWindow(@win)
        end

        # This moves the alphalist field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@win, @shadow_win]
          subwidgets = [@entry_field, @scroll_field]
          move_specific(xplace, yplace, relative, refresh_flag,
                        windows, subwidgets)
        end

        # The alphalist's focus resides in the entry widget. But the scroll widget
        # will not draw items highlighted unless it has focus. Temporarily adjust
        # the focus of the scroll widget when drawing on it to get the right
        # highlighting.
        def saveFocus
          @save = @scroll_field.has_focus
          @scroll_field.has_focus = @entry_field.has_focus
        end

        def restoreFocus
          @scroll_field.has_focus = @save
        end

        def drawMyScroller
          saveFocus
          @scroll_field.draw(@scroll_field.box)
          restoreFocus
        end

        def injectMyScroller(key)
          saveFocus
          @scroll_field.inject(key)
          restoreFocus
        end

        # This draws the alphalist widget.
        def draw(_box)
          # Does this widget have a shadow?
          Draw.draw_shadow(@shadow_win) unless @shadow_win.nil?

          # Draw in the entry field.
          @entry_field.draw(@entry_field.box)

          # Draw in the scroll field.
          drawMyScroller
        end

        # This activates the alphalist
        def activate(actions)
          # Draw the widget.
          draw(@box)

          # Activate the widget.
          ret = @entry_field.activate(actions)

          # Copy the exit type from the entry field.
          @exit_type = @entry_field.exit_type

          # Determine the exit status.
          return ret if @exit_type != :EARLY_EXIT

          0
        end

        # This injects a single character into the alphalist.
        def inject(input)
          # Draw the widget.
          draw(@box)

          # Inject a character into the widget.
          ret = @entry_field.inject(input)

          # Copy the eixt type from the entry field.
          @exit_type = @entry_field.exit_type

          # Determine the exit status.
          ret = -1 if @exit_type == :EARLY_EXIT

          @result_data = ret
          ret
        end

        # This sets multiple attributes of the widget.
        def set(list, list_size, filler_char, highlight, box)
          setContents(list, list_size)
          setFillerChar(filler_char)
          setHighlight(highlight)
          set_box(box)
        end

        # This function sets the information inside the alphalist.
        def setContents(list, list_size)
          return unless createList(list, list_size)

          # Set the information in the scrolling list.
          @scroll_field.set(@list, @list_size, false,
                            @scroll_field.highlight, @scroll_field.box)

          # Clean out the entry field.
          setCurrentItem(0)
          @entry_field.clean

          # Redraw the widget.
          erase
          draw(@box)
        end

        # This returns the contents of the widget.
        def getContents(size)
          size << @list_size
          @list
        end

        # Get/set the current position in the scroll widget.
        def getCurrentItem
          @scroll_field.getCurrentItem
        end

        def setCurrentItem(item)
          return unless @list_size != 0

          @scroll_field.setCurrentItem(item)
          @entry_field.setValue(@list[@scroll_field.getCurrentItem])
        end

        # This sets the filler character of the entry field of the alphalist.
        def setFillerChar(filler_character)
          @filler_char = filler_character
          @entry_field.setFillerChar(filler_character)
        end

        def getFillerChar
          @filler_char
        end

        # This sets the highlgith bar attributes
        def setHighlight(highlight)
          @highlight = highlight
        end

        def getHighlight
          @highlight
        end

        # These functions set the drawing characters of the widget.
        def setMyULchar(character)
          @entry_field.set_upper_left_corner_char(character)
        end

        def setMyURchar(character)
          @entry_field.set_upper_right_corner_char(character)
        end

        def setMyLLchar(character)
          @scroll_field.set_lower_left_corner_char(character)
        end

        def setMyLRchar(character)
          @scroll_field.set_lower_right_corner_char(character)
        end

        def setMyVTchar(character)
          @entry_field.set_vertical_line_char(character)
          @scroll_field.set_vertical_line_char(character)
        end

        def setMyHZchar(character)
          @entry_field.set_horizontal_line_char(character)
          @scroll_field.set_horizontal_line_char(character)
        end

        def setMyBXattr(character)
          @entry_field.set_box_attr(character)
          @scroll_field.set_box_attr(character)
        end

        # This sets the background attribute of the widget.
        def setBKattr(attrib)
          @entry_field.setBKattr(attrib)
          @scroll_field.setBKattr(attrib)
        end

        def destroyInfo
          @list = String.new
          @list_size = 0
        end

        # This destroys the alpha list
        def destroy
          destroyInfo

          # Clean the key bindings.
          clean_bindings(:AlphaList)

          @entry_field.destroy
          @scroll_field.destroy

          # Free up the window pointers.
          Slithernix::Cdk.deleteCursesWindow(@shadow_win)
          Slithernix::Cdk.deleteCursesWindow(@win)

          # Unregister the widget.
          Slithernix::Cdk::Screen.unregister(:AlphaList, self)
        end

        # This function sets the pre-process function.
        def set_pre_process(callback, data)
          @entry_field.set_pre_process(callback, data)
        end

        # This function sets the post-process function.
        def set_post_process(callback, data)
          @entry_field.set_post_process(callback, data)
        end

        def createList(list, list_size)
          if list_size >= 0
            newlist = []

            # Copy in the new information.
            status = true
            (0...list_size).each do |x|
              newlist << list[x]
              if (newlist[x])&.size&.zero?
                status = false
                break
              end
            end
            if status
              destroyInfo
              @list_size = list_size
              @list = newlist
              @list.sort!
            end
          else
            destroyInfo
            status = true
          end
          status
        end

        def focus
          entry_field.focus
        end

        def unfocus
          entry_field.unfocus
        end

        def self.isFullWidth(width)
          width == Slithernix::Cdk::FULL || (Curses.cols != 0 && width >= Curses.cols)
        end

        def position
          super(@win)
        end
      end
    end
  end
end
