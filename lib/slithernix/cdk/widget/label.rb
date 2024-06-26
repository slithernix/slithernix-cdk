require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class Label < Slithernix::Cdk::Widget
        attr_accessor :win

        def initialize(cdkscreen, xplace, yplace, mesg, rows, box, shadow)
          super()
          parent_width = cdkscreen::window.maxx
          parent_height = cdkscreen::window.maxy
          box_width = -2**30  # -INFINITY
          box_height = 0
          xpos = [xplace]
          ypos = [yplace]
          x = 0

          if rows <= 0
            return nil
          end

          self.setBox(box)
          box_height = rows + 2 * @border_size

          @info = []
          @info_len = []
          @info_pos = []

          # Determine the box width.
          (0...rows).each do |x|
            #Translate the string to a chtype array
            info_len = []
            info_pos = []
            @info << Slithernix::Cdk.char2Chtype(mesg[x], info_len, info_pos)
            @info_len << info_len[0]
            @info_pos << info_pos[0]
            box_width = [box_width, @info_len[x]].max
          end
          box_width += 2 * @border_size

          # Create the string alignments.
          (0...rows).each do |x|
            @info_pos[x] = Slithernix::Cdk.justifyString(box_width - 2 * @border_size,
                                             @info_len[x], @info_pos[x])
          end

          # Make sure we didn't extend beyond the dimensions of the window.
          box_width = if box_width > parent_width
                      then parent_width
                      else box_width
                      end
          box_height = if box_height > parent_height
                       then parent_height
                       else box_height
                       end

          # Rejustify the x and y positions if we need to
          Slithernix::Cdk.alignxy(cdkscreen.window, xpos, ypos, box_width, box_height)
          @screen = cdkscreen
          @parent = cdkscreen.window
          @win = Curses::Window.new(box_height, box_width, ypos[0], xpos[0])
          @shadow_win = nil
          @xpos = xpos[0]
          @ypos = ypos[0]
          @rows = rows
          @box_width = box_width
          @box_height = box_height
          @input_window = @win
          @has_focus = false
          @shadow = shadow

          if @win.nil?
            self.destroy
            return nil
          end

          @win.keypad(true)

          # If a shadow was requested, then create the shadow window.
          if shadow
            @shadow_win = Curses::Window.new(box_height, box_width,
                ypos[0] + 1, xpos[0] + 1)
          end

          # Register this
          cdkscreen.register(:Label, self)
        end

        # This was added for the builder.
        def activate(actions)
          self.draw(@box)
        end

        # This sets multiple attributes of the widget
        def set(mesg, lines, box)
          self.setMessage(mesg, lines)
          self.setBox(box)
        end

        # This sets the information within the label.
        def setMessage(info, info_size)
          # Clean out the old message.`
          (0...@rows).each do |x|
            @info[x] = ''
            @info_pos[x] = 0
            @info_len[x] = 0
          end

          @rows = if info_size < @rows
                  then info_size
                  else @rows
                  end

          # Copy in the new message.
          (0...@rows).each do |x|
            info_len = []
            info_pos = []
            @info[x] = Slithernix::Cdk.char2Chtype(info[x], info_len, info_pos)
            @info_len[x] = info_len[0]
            @info_pos[x] = Slithernix::Cdk.justifyString(@box_width - 2 * @border_size,
                                             @info_len[x], info_pos[0])
          end

          # Redraw the label widget.
          self.erase
          self.draw(@box)
        end

        def getMessage(size)
          size << @rows
          return @info
        end

        def position
          super(@win)
        end

        # This sets the background attribute of the widget.
        def setBKattr(attrib)
          @win.wbkgd(attrib)
        end

        # This draws the label widget.
        def draw(box)
          # Is there a shadow?
          unless @shadow_win.nil?
            Slithernix::Cdk::Draw.drawShadow(@shadow_win)
          end

          # Box the widget if asked.
          if @box
            Slithernix::Cdk::Draw.drawObjBox(@win, self)
          end

          # Draw in the message.
          (0...@rows).each do |x|
            Slithernix::Cdk::Draw.writeChtype(@win,
                             @info_pos[x] + @border_size, x + @border_size,
                             @info[x], Slithernix::Cdk::HORIZONTAL, 0, @info_len[x])
          end

          # Refresh the window
          @win.refresh
        end

        # This erases the label widget
        def erase
          Slithernix::Cdk.eraseCursesWindow(@win)
          Slithernix::Cdk.eraseCursesWindow(@shadow_win)
        end

        # This moves the label field to the given location
        # Inherited
        # def move(xplace, yplace, relative, refresh_flag)
        # end

        # This destroys the label widget pointer.
        def destroy
          Slithernix::Cdk.deleteCursesWindow(@shadow_win)
          Slithernix::Cdk.deleteCursesWindow(@win)

          self.cleanBindings(:Label)

          Slithernix::Cdk::Screen.unregister(:Label, self)
        end

        # This pauses until a user hits a key...
        def wait(key)
          function_key = []
          if key.ord == 0
            code = self.getch(function_key)
          else
            # Only exit when a specific key is hit
            while true
              code = self.getch(function_key)
              if code == key
                break
              end
            end
          end
          return code
        end
      end
    end
  end
end
