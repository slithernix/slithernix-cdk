# frozen_string_literal: true

require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class Label < Slithernix::Cdk::Widget
        attr_accessor :win

        def initialize(cdkscreen, xplace, yplace, mesg, rows, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          box_width = -2**30 # -INFINITY
          xpos = [xplace]
          ypos = [yplace]

          return nil if rows <= 0

          set_box(box)
          box_height = rows + (2 * @border_size)

          @info = []
          @info_len = []
          @info_pos = []

          # Determine the box width.
          (0...rows).each do |x|
            # Translate the string to a chtype array
            info_len = []
            info_pos = []
            @info << Slithernix::Cdk.char_to_chtype(mesg[x], info_len, info_pos)
            @info_len << info_len[0]
            @info_pos << info_pos[0]
            box_width = [box_width, @info_len[x]].max
          end
          box_width += 2 * @border_size

          # Create the string alignments.
          (0...rows).each do |x|
            @info_pos[x] = Slithernix::Cdk.justify_string(box_width - (2 * @border_size),
                                                          @info_len[x], @info_pos[x])
          end

          # Make sure we didn't extend beyond the dimensions of the window.
          box_width = parent_width if box_width > parent_width
          box_height = parent_height if box_height > parent_height

          # Rejustify the x and y positions if we need to
          Slithernix::Cdk.alignxy(cdkscreen.window, xpos, ypos, box_width,
                                  box_height)
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
            destroy
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
        def activate(_actions)
          draw(@box)
        end

        # This sets multiple attributes of the widget
        def set(mesg, lines, box)
          set_message(mesg, lines)
          set_box(box)
        end

        # This sets the information within the label.
        def set_message(info, info_size)
          # Clean out the old message.`
          (0...@rows).each do |x|
            @info[x] = String.new
            @info_pos[x] = 0
            @info_len[x] = 0
          end

          @rows = [info_size, @rows].min

          # Copy in the new message.
          (0...@rows).each do |x|
            info_len = []
            info_pos = []
            @info[x] = Slithernix::Cdk.char_to_chtype(info[x], info_len, info_pos)
            @info_len[x] = info_len[0]
            @info_pos[x] = Slithernix::Cdk.justify_string(@box_width - (2 * @border_size),
                                                          @info_len[x], info_pos[0])
          end

          # Redraw the label widget.
          erase
          draw(@box)
        end

        def get_message(size)
          size << @rows
          @info
        end

        def position
          super(@win)
        end

        # This sets the background attribute of the widget.
        def set_background_attr(attrib)
          @win.wbkgd(attrib)
        end

        # This draws the label widget.
        def draw(_box)
          # Is there a shadow?
          unless @shadow_win.nil?
            Slithernix::Cdk::Draw.draw_shadow(@shadow_win)
          end

          # Box the widget if asked.
          Slithernix::Cdk::Draw.draw_obj_box(@win, self) if @box

          # Draw in the message.
          (0...@rows).each do |x|
            Slithernix::Cdk::Draw.write_chtype(
              @win,
              @info_pos[x] + @border_size,
              x + @border_size,
              @info[x],
              Slithernix::Cdk::HORIZONTAL,
              0,
              @info_len[x]
            )
          end

          # Refresh the window
          @win.refresh
        end

        # This erases the label widget
        def erase
          Slithernix::Cdk.erase_curses_window(@win)
          Slithernix::Cdk.erase_curses_window(@shadow_win)
        end

        # This moves the label field to the given location
        # Inherited
        # def move(xplace, yplace, relative, refresh_flag)
        # end

        # This destroys the label widget pointer.
        def destroy
          Slithernix::Cdk.delete_curses_window(@shadow_win)
          Slithernix::Cdk.delete_curses_window(@win)

          clean_bindings(:Label)

          Slithernix::Cdk::Screen.unregister(:Label, self)
        end

        # This pauses until a user hits a key...
        def wait(key)
          function_key = []
          if key.ord.zero?
            code = getch(function_key)
          else
            # Only exit when a specific key is hit
            loop do
              code = getch(function_key)
              break if code == key
            end
          end
          code
        end
      end
    end
  end
end
