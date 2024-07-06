require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class Dialog < Slithernix::Cdk::Widget
        attr_reader :current_button

        MIN_DIALOG_WIDTH = 10

        def initialize(cdkscreen, xplace, yplace, mesg, rows, button_label,
                       button_count, highlight, separator, box, shadow)
          super()
          box_width = Dialog::MIN_DIALOG_WIDTH
          max_message_width = -1
          button_width = 0
          xpos = xplace
          ypos = yplace
          temp = 0
          buttonadj = 0
          @info = []
          @info_len = []
          @info_pos = []
          @button_label = []
          @button_len = []
          @button_pos = []

          if rows <= 0 || button_count <= 0
            destroy
            return nil
          end

          setBox(box)
          box_height = separator ? 1 : 0
          box_height += rows + (2 * @border_size) + 1

          # Translate the string message to a chtype array
          (0...rows).each do |x|
            info_len = []
            info_pos = []
            @info << Slithernix::Cdk.char2Chtype(mesg[x], info_len, info_pos)
            @info_len << info_len[0]
            @info_pos << info_pos[0]
            max_message_width = [max_message_width, info_len[0]].max
          end

          # Translate the button label string to a chtype array
          (0...button_count).each do |x|
            button_len = []
            @button_label << Slithernix::Cdk.char2Chtype(button_label[x],
                                                         button_len, [])
            @button_len << button_len[0]
            button_width += button_len[0] + 1
          end

          button_width -= 1

          # Determine the final dimensions of the box.
          box_width = [box_width, max_message_width, button_width].max
          box_width = box_width + 2 + (2 * @border_size)

          # Now we have to readjust the x and y positions.
          xtmp = [xpos]
          ytmp = [ypos]
          Slithernix::Cdk.alignxy(cdkscreen.window, xtmp, ytmp, box_width,
                                  box_height)
          xpos = xtmp[0]
          ypos = ytmp[0]

          # Set up the dialog box attributes.
          @screen = cdkscreen
          @parent = cdkscreen.window
          @win = Curses::Window.new(box_height, box_width, ypos, xpos)
          @shadow_win = nil
          @button_count = button_count
          @current_button = 0
          @message_rows = rows
          @box_height = box_height
          @box_width = box_width
          @highlight = highlight
          @separator = separator
          @accepts_focus = true
          @input_window = @win
          @shadow = shadow

          # If we couldn't create the window, we should return a nil value.
          if @win.nil?
            destroy
            return nil
          end
          @win.keypad(true)

          # Find the button positions.
          buttonadj = (box_width - button_width) / 2
          (0...button_count).each do |x|
            @button_pos[x] = buttonadj
            buttonadj = buttonadj + @button_len[x] + @border_size
          end

          # Create the string alignments.
          (0...rows).each do |x|
            @info_pos[x] = Slithernix::Cdk.justifyString(box_width - (2 * @border_size),
                                                         @info_len[x], @info_pos[x])
          end

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
          cdkscreen.register(:Dialog, self)
        end

        # This lets the user select the button.
        def activate(actions)
          input = 0

          # Draw the dialog box.
          draw(@box)

          # Lets move to the first button.
          Slithernix::Cdk::Draw.writeChtypeAttrib(
            @win,
            @button_pos[@current_button],
            @box_height - 1 - @border_size,
            @button_label[@current_button],
            @highlight,
            Slithernix::Cdk::HORIZONTAL,
            0,
            @button_len[@current_button],
          )

          @win.refresh

          if actions.nil? || actions.size.zero?
            while true
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

          # Set the exit type and exit
          setExitType(0)
          -1
        end

        # This injects a single character into the dialog widget
        def inject(input)
          first_button = 0
          last_button = @button_count - 1
          pp_return = 1
          ret = -1
          complete = false

          # Set the exit type.
          setExitType(0)

          # Check if there is a pre-process function to be called.
          unless @pre_process_func.nil?
            pp_return = @pre_process_func.call(:Dialog, self,
                                               @pre_process_data, input)
          end

          # Should we continue?
          if pp_return != 0
            # Check for a key binding.
            if checkBind(:Dialog, input)
              complete = true
            else
              case input
              when Curses::KEY_LEFT, Curses::KEY_BTAB, Curses::KEY_BACKSPACE
                if @current_button == first_button
                  @current_button = last_button
                else
                  @current_button -= 1
                end
              when Curses::KEY_RIGHT, Slithernix::Cdk::KEY_TAB, ' '.ord
                if @current_button == last_button
                  @current_button = first_button
                else
                  @current_button += 1
                end
              when Curses::KEY_UP, Curses::KEY_DOWN
                Slithernix::Cdk.Beep
              when Slithernix::Cdk::REFRESH
                @screen.erase
                @screen.refresh
              when Slithernix::Cdk::KEY_ESC
                setExitType(input)
                complete = true
              when Curses::Error
                setExitType(input)
              when Curses::KEY_ENTER, Slithernix::Cdk::KEY_RETURN
                setExitType(input)
                ret = @current_button
                complete = true
              end
            end

            # Should we call a post_process?
            if !complete and @post_process_func
              @post_process_func.call(:Dialog, self,
                                      @post_process_data, input)
            end
          end

          unless complete
            drawButtons
            @win.refresh
            setExitType(0)
          end

          @result_data = ret
          ret
        end

        # This moves the dialog field to the given location.
        # Inherited
        # def move(xplace, yplace, relative, refresh_flag)
        # end

        # This function draws the dialog widget.
        def draw(box)
          # Is there a shadow?
          Slithernix::Cdk::Draw.drawShadow(@shadow_win) unless @shadow_win.nil?

          # Box the widget if they asked.
          Slithernix::Cdk::Draw.drawObjBox(@win, self) if box

          # Draw in the message.
          (0...@message_rows).each do |x|
            Slithernix::Cdk::Draw.writeChtype(@win,
                                              @info_pos[x] + @border_size, x + @border_size, @info[x],
                                              Slithernix::Cdk::HORIZONTAL, 0, @info_len[x])
          end

          # Draw in the buttons.
          drawButtons

          @win.refresh
        end

        # This function destroys the dialog widget.
        def destroy
          # Clean up the windows.
          Slithernix::Cdk.deleteCursesWindow(@win)
          Slithernix::Cdk.deleteCursesWindow(@shadow_win)

          # Clean the key bindings
          cleanBindings(:Dialog)

          # Unregister this widget
          Slithernix::Cdk::Screen.unregister(:Dialog, self)
        end

        # This function erases the dialog widget from the screen.
        def erase
          return unless validCDKObject

          Slithernix::Cdk.eraseCursesWindow(@win)
          Slithernix::Cdk.eraseCursesWindow(@shadow_win)
        end

        # This sets attributes of the dialog box.
        def set(highlight, separator, box)
          setHighlight(highlight)
          setSeparator(separator)
          setBox(box)
        end

        # This sets the highlight attribute for the buttons.
        def setHighlight(highlight)
          @highlight = highlight
        end

        def getHighlight
          @highlight
        end

        # This sets whether or not the dialog box will have a separator line.
        def setSeparator(separator)
          @separator = separator
        end

        def getSeparator
          @separator
        end

        # This sets the background attribute of the widget.
        def setBKattr(attrib)
          @win.wbkgd(attrib)
        end

        # This draws the dialog buttons and the separation line.
        def drawButtons
          (0...@button_count).each do |x|
            Slithernix::Cdk::Draw.writeChtype(
              @win,
              @button_pos[x],
              @box_height - 1 - @border_size,
              @button_label[x],
              Slithernix::Cdk::HORIZONTAL,
              0,
              @button_len[x],
            )
          end

          # Draw the separation line.
          if @separator
            boxattr = @BXAttr

            (1...@box_width).each do |x|
              @win.mvwaddch(
                @box_height - 2 - @border_size,
                x,
                Slithernix::Cdk::ACS_HLINE | boxattr,
              )
            end

            @win.mvwaddch(
              @box_height - 2 - @border_size,
              0,
              Slithernix::Cdk::ACS_LTEE | boxattr,
            )

            @win.mvwaddch(
              @box_height - 2 - @border_size,
              @win.maxx - 1,
              Slithernix::Cdk::ACS_RTEE | boxattr,
            )
          end

          Slithernix::Cdk::Draw.writeChtypeAttrib(
            @win,
            @button_pos[@current_button],
            @box_height - 1 - @border_size,
            @button_label[@current_button],
            @highlight,
            Slithernix::Cdk::HORIZONTAL,
            0,
            @button_len[@current_button],
          )
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
