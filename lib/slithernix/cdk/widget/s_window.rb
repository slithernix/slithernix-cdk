# frozen_string_literal: true

require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class SWindow < Slithernix::Cdk::Widget
        def initialize(cdkscreen, xplace, yplace, height, width, title,
                       save_lines, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          bindings = {
            Slithernix::Cdk::BACKCHAR => Curses::KEY_PPAGE,
            'b' => Curses::KEY_PPAGE,
            'B' => Curses::KEY_PPAGE,
            Slithernix::Cdk::FORCHAR => Curses::KEY_NPAGE,
            ' ' => Curses::KEY_NPAGE,
            'f' => Curses::KEY_NPAGE,
            'F' => Curses::KEY_NPAGE,
            '|' => Curses::KEY_HOME,
            '$' => Curses::KEY_END
          }

          setBox(box)

          # If the height is a negative value, the height will be
          # ROWS-height, otherwise the height will be the given height.
          box_height = Slithernix::Cdk.setWidgetDimension(parent_height,
                                                          height, 0)

          # If the width is a negative value, the width will be
          # COLS-width, otherwise the widget will be the given width.
          box_width = Slithernix::Cdk.setWidgetDimension(parent_width, width,
                                                         0)
          box_width = setTitle(title, box_width)

          # Set the box height.
          box_height += @title_lines + 1

          # Make sure we didn't extend beyond the dimensions of the window.
          box_width = [box_width, parent_width].min
          box_height = [box_height, parent_height].min

          # Set the rest of the variables.
          @title_adj = @title_lines + 1

          # Rejustify the x and y positions if we need to.
          xtmp = [xplace]
          ytmp = [yplace]
          Slithernix::Cdk.alignxy(cdkscreen.window, xtmp, ytmp, box_width,
                                  box_height)
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Make the scrolling window.
          @win = Curses::Window.new(box_height, box_width, ypos, xpos)
          if @win.nil?
            destroy
            return nil
          end
          @win.keypad(true)

          # Make the field window
          @field_win = @win.subwin(
            box_height - @title_lines - 2,
            box_width - 2,
            ypos + @title_lines + 1,
            xpos + 1
          )

          @field_win.keypad(true)

          # Set the rest of the variables
          @screen = cdkscreen
          @parent = cdkscreen.window
          @shadow_win = nil
          @box_height = box_height
          @box_width = box_width
          @view_size = box_height - @title_lines - 2
          @current_top = 0
          @max_top_line = 0
          @left_char = 0
          @max_left_char = 0
          @list_size = 0
          @widest_line = -1
          @save_lines = save_lines
          @accepts_focus = true
          @input_window = @win
          @shadow = shadow

          unless createList(save_lines)
            destroy
            return nil
          end

          # Do we need to create a shadow?
          if shadow
            @shadow_win = Curses::Window.new(
              box_height,
              box_width,
              ypos + 1,
              xpos + 1
            )
          end

          # Create the key bindings
          bindings.each do |from, to|
            bind(:SWindow, from, :getc, to)
          end

          # Register this baby.
          cdkscreen.register(:SWindow, self)
        end

        # This sets the lines and the box attribute of the scrolling window.
        def set(list, lines, box)
          setContents(list, lines)
          setBox(box)
        end

        def setupLine(list, x)
          list_len = []
          list_pos = []
          @list[x] = Slithernix::Cdk.char2Chtype(list, list_len, list_pos)
          @list_len[x] = list_len[0]
          @list_pos[x] = Slithernix::Cdk.justifyString(
            @box_width,
            list_len[0],
            list_pos[0],
          )
          @widest_line = [@widest_line, @list_len[x]].max
        end

        # This sets all the lines inside the scrolling window.
        def setContents(list, list_size)
          # First let's clean all the lines in the window.
          clean
          createList(list_size)

          # Now let's set all the lines inside the window.
          (0...list_size).each do |x|
            setupLine(list[x], x)
          end

          # Set some more important members of the scrolling window.
          @list_size = list_size
          @max_top_line = @list_size - @view_size
          @max_top_line = [@max_top_line, 0].max
          @max_left_char = @widest_line - (@box_width - 2)
          @current_top = 0
          @left_char = 0
        end

        def getContents(size)
          size << @list_size
          @list
        end

        def freeLine(x)
          #  if x < @list_size
          #    @list[x] = 0
          #  end
        end

        # This adds a line to the scrolling window.
        def add(list, insert_pos)
          # If we are at the maximum number of save lines erase the first
          # position and bump everything up one spot
          if (@list_size == @save_lines) && @list_size.positive?
            @list = @list[1..]
            @list_pos = @list_pos[1..]
            @list_len = @list_len[1..]
            @list_size -= 1
          end

          # Determine where the line is being added.
          if insert_pos == Slithernix::Cdk::TOP
            # We need to 'bump' everything down one line...
            @list = [@list[0]] + @list
            @list_pos = [@list_pos[0]] + @list_pos
            @list_len = [@list_len[0]] + @list_len

            # Add it into the scrolling window.
            setupLine(list, 0)

            # set some variables.
            @current_top = 0
            @list_size += 1 if @list_size < @save_lines

            # Set the maximum top line.
            @max_top_line = @list_size - @view_size
            @max_top_line = [@max_top_line, 0].max

            @max_left_char = @widest_line - (@box_width - 2)
          else
            # Add to the bottom.
            @list += ['']
            @list_pos += [0]
            @list_len += [0]
            setupLine(list, @list_size)

            @max_left_char = @widest_line - (@box_width - 2)

            # Increment the item count and zero out the next row.
            if @list_size < @save_lines
              @list_size += 1
              freeLine(@list_size)
            end

            # Set the maximum top line.
            if @list_size <= @view_size
              @max_top_line = 0
              @current_top = 0
            else
              @max_top_line = @list_size - @view_size
              @current_top = @max_top_line
            end
          end

          # Draw in the list.
          drawList(@box)
        end

        # This jumps to a given line.
        def jumpToLine(line)
          # Make sure the line is in bounds.
          @current_top = if line == Slithernix::Cdk::BOTTOM || line >= @list_size
                           # We are moving to the last page.
                           @list_size - @view_size
                         elsif line == TOP || line <= 0
                           # We are moving to the top of the page.
                           0
                         elsif @view_size + line < @list_size
                           # We are moving in the middle somewhere.
                           line
                         else
                           @list_size - @view_size
                         end

          # A little sanity check to make sure we don't do something silly
          @current_top = 0 if @current_top.negative?

          # Redraw the window.
          draw(@box)
        end

        # This removes all the lines inside the scrolling window.
        def clean
          # Clean up the memory used...
          (0...@list_size).each do |x|
            freeLine(x)
          end

          # Reset some variables.
          @list_size = 0
          @max_left_char = 0
          @widest_line = 0
          @current_top = 0
          @max_top_line = 0

          # Redraw the window.
          draw(@box)
        end

        # This trims lines from the scrolling window.
        def trim(begin_line, end_line)
          # Check the value of begin_line
          start = if begin_line.negative?
                    0
                  elsif begin_line >= @list_size
                    @list_size - 1
                  else
                    begin_line
                  end

          # Check the value of end_line
          finish = if end_line.negative?
                     0
                   elsif end_line >= @list_size
                     @list_size - 1
                   else
                     end_line
                   end

          # Make sure the start is lower than the end.
          return if start > finish

          # Start nuking elements from the window
          (start..finish).each do |x|
            freeLine(x)

            next unless x < list_size - 1

            @list[x] = @list[x + 1]
            @list_pos[x] = @list_pos[x + 1]
            @list_len[x] = @list_len[x + 1]
          end

          # Adjust the item count correctly.
          @list_size = @list_size - (end_line - begin_line) - 1

          # Redraw the window.
          draw(@box)
        end

        # This allows the user to play inside the scrolling window.
        def activate(actions)
          # Draw the scrolling list.
          draw(@box)

          if actions.nil? || actions.empty?
            loop do
              input = getch([])

              # inject the character into the widget.
              inject(input)
              return if @exit_type != :EARLY_EXIT
            end
          else
            # Inject each character one at a time
            actions.each do |action|
              inject(action)
              return if @exit_type != :EARLY_EXIT
            end
          end

          # Set the exit type and return.
          setExitType(0)
        end

        # This injects a single character into the widget.
        def inject(input)
          pp_return = 1
          ret = -1
          complete = false

          # Set the exit type.
          setExitType(0)

          # Draw the window....
          draw(@box)

          # Check if there is a pre-process function to be called.
          unless @pre_process_func.nil?
            # Call the pre-process function.
            pp_return = @pre_process_func.call(:SWindow, self,
                                               @pre_process_data, input)
          end

          # Should we continue?
          if pp_return != 0
            # Check for a key binding.
            if checkBind(:SWindow, input)
              complete = true
            else
              case input
              when Curses::KEY_UP
                if @current_top.positive?
                  @current_top -= 1
                else
                  Slithernix::Cdk.Beep
                end
              when Curses::KEY_DOWN
                if @current_top >= 0 && @current_top < @max_top_line
                  @current_top += 1
                else
                  Slithernix::Cdk.Beep
                end
              when Curses::KEY_RIGHT
                if @left_char < @max_left_char
                  @left_char += 1
                else
                  Slithernix::Cdk.Beep
                end
              when Curses::KEY_LEFT
                if @left_char.positive?
                  @left_char -= 1
                else
                  Slithernix::Cdk.Beep
                end
              when Curses::KEY_PPAGE
                if @current_top.zero?
                  Slithernix::Cdk.Beep
                else
                  @current_top = if @current_top >= @view_size
                                   @current_top - (@view_size - 1)
                                 else
                                   0
                                 end
                end
              when Curses::KEY_NPAGE
                if @current_top == @max_top_line
                  Slithernix::Cdk.Beep
                else
                  @current_top = if @current_top + @view_size < @max_top_line
                                   @current_top + (@view_size - 1)
                                 else
                                   @max_top_line
                                 end
                end
              when Curses::KEY_HOME
                @left_char = 0
              when Curses::KEY_END
                @left_char = @max_left_char + 1
              when 'g', '1', '<'
                @current_top = 0
              when 'G', '>'
                @current_top = @max_top_line
              when 'l', 'L'
                loadInformation
              when 's', 'S'
                saveInformation
              when Slithernix::Cdk::KEY_TAB, Slithernix::Cdk::KEY_RETURN, Curses::KEY_ENTER
                setExitType(input)
                ret = 1
                complete = true
              when Slithernix::Cdk::KEY_ESC
                setExitType(input)
                complete = true
              when Curses::Error
                setExitType(input)
                complete = true
              when Slithernix::Cdk::REFRESH
                @screen.erase
                @screen.refresh
              end
            end

            # Should we call a post-process?
            if !complete && @post_process_func
              @post_process_func.call(:SWindow, self, @post_process_data,
                                      input)
            end
          end

          unless complete
            drawList(@box)
            setExitType(0)
          end

          @return_data = ret
          ret
        end

        # This moves the window field to the given location.
        # Inherited
        # def move(xplace, yplace, relative, refresh_flag)
        # end

        # This function draws the swindow window widget.
        def draw(box)
          # Do we need to draw in the shadow.
          Slithernix::Cdk::Draw.draw_shadow(@shadow_win) unless @shadow_win.nil?

          # Box the widget if needed
          Slithernix::Cdk::Draw.draw_obj_box(@win, self) if box

          drawTitle(@win)

          @win.refresh

          # Draw in the list.
          drawList(box)
        end

        # This draws in the contents of the scrolling window
        def drawList(_box)
          # Determine the last line to draw.
          last_line = [@list_size, @view_size].min

          # Erase the scrolling window.
          @field_win.erase

          # Start drawing in each line.
          (0...last_line).each do |x|
            screen_pos = @list_pos[x + @current_top] - @left_char

            # Write in the correct line.
            if screen_pos >= 0
              Slithernix::Cdk::Draw.write_chtype(@field_win, screen_pos, x,
                                                 @list[x + @current_top], Slithernix::Cdk::HORIZONTAL, 0,
                                                 @list_len[x + @current_top])
            else
              Slithernix::Cdk::Draw.write_chtype(@field_win, 0, x, @list[x + @current_top],
                                                 Slithernix::Cdk::HORIZONTAL, @left_char - @list_pos[x + @current_top],
                                                 @list_len[x + @current_top])
            end
          end

          @field_win.refresh
        end

        # This sets the background attribute of the widget.
        def setBKattr(attrib)
          @win.wbkgd(attrib)
          @field_win.wbkgd(attrib)
        end

        # Free any storage associated with the info-list.
        def destroyInfo
          @list = []
          @list_pos = []
          @list_len = []
        end

        # This function destroys the scrolling window widget.
        def destroy
          destroyInfo

          cleanTitle

          # Delete the windows.
          Slithernix::Cdk.deleteCursesWindow(@shadow_win)
          Slithernix::Cdk.deleteCursesWindow(@field_win)
          Slithernix::Cdk.deleteCursesWindow(@win)

          # Clean the key bindings.
          cleanBindings(:SWindow)

          # Unregister this widget.
          Slithernix::Cdk::Screen.unregister(:SWindow, self)
        end

        # This function erases the scrolling window widget.
        def erase
          return unless validCDKObject

          Slithernix::Cdk.eraseCursesWindow(@win)
          Slithernix::Cdk.eraseCursesWindow(@shadow_win)
        end

        # This execs a command and redirects the output to the scrolling window.
        def exec(command, insert_pos)
          count = -1
          Curses.close_screen

          # Try to open the command.
          begin
            unless (ps = IO.popen(command.split, 'r')).nil?
              # Start reading.
              until (temp = ps.gets).nil?
                temp = temp[0...-1] if !temp.empty? && temp[-1] == '\n'
                # Add the line to the scrolling window.
                add(temp, insert_pos)
                count += 1
              end

              # Close the pipe
              ps.close
            end
          rescue StandardError => e
            add(e.message, insert_pos)
          end

          count
        end

        def exec_interactive(command, insert_pos)
          count = -1

          # Try to open the command.
          begin
            unless (ps = IO.popen(command.split, 'r')).nil?
              # Start reading.
              until (temp = ps.gets).nil?
                temp = temp[0...-1] if !temp.empty? && temp[-1] == '\n'
                # Add the line to the scrolling window.
                add(temp, insert_pos)
                count += 1
              end

              # Close the pipe
              ps.close
            end
          rescue StandardError => e
            add(e.message, insert_pos)
          end

          count
        end

        def showMessage2(msg, msg2, filename)
          mesg = [
            msg,
            msg2,
            format('<C>(%s)', filename),
            ' ',
            '<C> Press any key to continue.',
          ]
          @screen.popupLabel(mesg, mesg.size)
        end

        # This function allows the user to dump the information from the
        # scrolling window to a file.
        def saveInformation
          # Create the entry field to get the filename.
          entry = Slithernix::Cdk::Widget::Entry.new(
            @screen,
            Slithernix::Cdk::CENTER,
            Slithernix::Cdk::CENTER,
            '<C></B/5>Enter the filename of the save file.',
            'Filename: ',
            Curses::A_NORMAL,
            '_'.ord,
            :MIXED,
            20,
            1,
            256,
            true,
            false
          )

          # Get the filename.
          filename = entry.activate([])

          # Did they hit escape?
          if entry.exit_type == :ESCAPE_HIT
            # Popup a message.
            mesg = [
              '<C></B/5>Save Canceled.',
              '<C>Escape hit. Scrolling window information not saved.',
              ' ',
              '<C>Press any key to continue.'
            ]
            @screen.popupLabel(mesg, 4)

            # Clean up and exit.
            entry.destroy
          end

          # Write the contents of the scrolling window to the file.
          lines_saved = dump(filename)

          # Was the save successful?
          if lines_saved == -1
            # Nope, tell 'em
            showMessage2('<C></B/16>Error', '<C>Could not save to the file.',
                         filename)
          else
            # Yep, let them know how many lines were saved.
            showMessage2(
              '<C></B/5>Save Successful',
              format('<C>There were %d lines saved to the file', lines_saved),
              filename
            )
          end

          # Clean up and exit.
          entry.destroy
          @screen.erase
          @screen.draw
        end

        # This function allows the user to load new information into the scrolling
        # window.
        def loadInformation
          # Create the file selector to choose the file.
          fselect = Slithernix::Cdk::Widget::FSelect.new(
            @screen,
            Slithernix::Cdk::CENTER,
            Slithernix::Cdk::CENTER,
            20,
            55,
            '<C>Load Which File',
            'Filename',
            Curses::A_NORMAL,
            '.',
            Curses::A_REVERSE,
            '</5>',
            '</48>',
            '</N>',
            '</N>',
            true,
            false
          )

          # Get the filename to load.
          fselect.activate([])

          # Make sure they selected a file.
          if fselect.exit_type == :ESCAPE_HIT
            # Popup a message.
            mesg = [
              '<C></B/5>Load Canceled.',
              ' ',
              '<C>Press any key to continue.',
            ]
            @screen.popupLabel(mesg, 3)

            # Clean up and exit
            fselect.destroy
            return
          end

          # Copy the filename and destroy the file selector.
          filename = fselect.pathname
          fselect.destroy

          # Maybe we should check before nuking all the information in the
          # scrolling window...
          if @list_size.positive?
            # Create the dialog message.
            mesg = [
              '<C></B/5>Save Information First',
              '<C>There is information in the scrolling window.',
              '<C>Do you want to save it to a file first?',
            ]
            button = ['(Yes)', '(No)']

            # Create the dialog widget.
            dialog = Slithernix::Cdk::Dialog.new(
              @screen,
              Slithernix::Cdk::CENTER,
              Slithernix::Cdk::CENTER,
              mesg,
              3,
              button,
              2,
              Curses.color_pair(2) | Curses::A_REVERSE,
              true,
              true,
              false
            )

            # Activate the widet.
            answer = dialog.activate([])
            dialog.destroy

            # Check the answer.
            if [-1, 0].include?(answer)
              # Save the information.
              saveInformation
            end
          end

          # Open the file and read it in.
          f = File.open(filename)
          file_info = f.readlines.map do |line|
            if line.size.positive? && line[-1] == "\n"
              line[0...-1]
            else
              line
            end
          end.compact

          # TODO: error handling
          # if (lines == -1)
          # {
          #   /* The file read didn't work. */
          #   showMessage2 (swindow,
          #                 "<C></B/16>Error",
          #                 "<C>Could not read the file",
          #                 filename);
          #   freeChar (filename);
          #   return;
          # }

          # Clean out the scrolling window.
          clean

          # Set the new information in the scrolling window.
          set(file_info, file_info.size, @box)
        end

        # This actually dumps the information from the scrolling window to a file.
        def dump(filename)
          # Try to open the file.
          # if ((outputFile = fopen (filename, "w")) == 0)
          # {
          #  return -1;
          # }
          output_file = File.new(filename, 'w')

          # Start writing out the file.
          @list.each do |item|
            raw_line = Slithernix::Cdk.chtype2Char(item)
            output_file << ("%s\n" % raw_line)
          end

          # Close the file and return the number of lines written.
          output_file.close
          @list_size
        end

        def focus
          draw(@box)
        end

        def unfocus
          draw(@box)
        end

        def createList(list_size)
          status = false

          if list_size >= 0
            new_list = []
            new_pos = []
            new_len = []

            status = true
            destroyInfo

            @list = new_list
            @list_pos = new_pos
            @list_len = new_len
          else
            destroyInfo
            status = false
          end
          status
        end

        def position
          super(@win)
        end
      end
    end
  end
end
