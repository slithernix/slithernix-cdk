# frozen_string_literal: true

module Slithernix
  module Cdk
    class Widget
      attr_accessor :screen_index,
                    :screen,
                    :has_focus,
                    :is_visible,
                    :box,
                    :upper_left_corner_char,
                    :upper_right_corner_char,
                    :lower_left_corner_character,
                    :lower_right_corner_character,
                    :horizontal_line_char,
                    :vertical_line_char,
                    :box_attr

      attr_reader :binding_list,
                  :accepts_focus,
                  :exit_type,
                  :border_size

      @@g_paste_buffer = String.new

      def initialize
        @has_focus = true
        @is_visible = true

        Slithernix::Cdk::ALL_OBJECTS << self

        # set default line-drawing characters
        @upper_left_corner_char = Slithernix::Cdk::ACS_ULCORNER
        @upper_right_corner_char = Slithernix::Cdk::ACS_URCORNER
        @lower_left_corner_character = Slithernix::Cdk::ACS_LLCORNER
        @lower_right_corner_character = Slithernix::Cdk::ACS_LRCORNER
        @horizontal_line_char = Slithernix::Cdk::ACS_HLINE
        @vertical_line_char = Slithernix::Cdk::ACS_VLINE
        @box_attr = Curses::A_NORMAL

        # set default exit-types
        @exit_type = :NEVER_ACTIVATED
        @early_exit = :NEVER_ACTIVATED

        @accepts_focus = false

        # Bound functions
        @binding_list = {}
      end

      def widget_type
        self.class.name.to_sym
      end

      def valid_widget_type(_type)
        # dummy version for now
        true
      end

      def screen_xpos(n)
        n + @border_size
      end

      def screen_ypos(n)
        n + @border_size + @title_lines
      end

      def draw(a); end

      def erase; end

      def move(xplace, yplace, relative, refresh_flag)
        move_specific(
          xplace,
          yplace,
          relative,
          refresh_flag,
          [@win, @shadow_win],
          [],
        )
      end

      def move_specific(xplace, yplace, relative, refresh_flag, windows, subwidgets)
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

        # Adjust the window if we need to
        xtmp = [xpos]
        ytmp = [ypos]
        Slithernix::Cdk.alignxy(
          @screen.window,
          xtmp,
          ytmp,
          @box_width,
          @box_height,
        )
        xpos = xtmp[0]
        ypos = ytmp[0]

        # Get the difference
        xdiff = current_x - xpos
        ydiff = current_y - ypos

        # Move the window to the new location.
        windows.each do |window|
          Slithernix::Cdk.move_curses_window(window, -xdiff, -ydiff)
        end

        subwidgets.each do |subwidget|
          subwidget.move(xplace, yplace, relative, refresh_flag)
        end

        # Touch the windows so they 'move'
        Slithernix::Cdk::Screen.refresh_window(@screen.window)

        # Redraw the window, if they asked for it
        draw(@box) if refresh_flag
      end

      def inject(a); end

      def set_box(box)
        @box = box
        @border_size = @box ? 1 : 0
      end

      def get_box
        @box
      end

      def focus; end

      def unfocus; end

      def save_data; end

      def refresh_data; end

      def destroy; end

      # Set the widget's upper-left-corner line-drawing character.
      def set_upper_left_corner_char(ch)
        @upper_left_corner_char = ch
      end

      # Set the widget's upper-right-corner line-drawing character.
      def set_upper_right_corner_char(ch)
        @upper_right_corner_char = ch
      end

      # Set the widget's lower-left-corner line-drawing character.
      def set_lower_left_corner_char(ch)
        @lower_left_corner_character = ch
      end

      # Set the widget's lower-right-corner line-drawing character.
      def set_lower_right_corner_char(ch)
        @lower_right_corner_character = ch
      end

      # Set the widget's horizontal line-drawing character
      def set_horizontal_line_char(ch)
        @horizontal_line_char = ch
      end

      # Set the widget's vertical line-drawing character
      def set_vertical_line_char(ch)
        @vertical_line_char = ch
      end

      # Set the widget's box-attributes.
      def set_box_attr(ch)
        @box_attr = ch
      end

      # This sets the background color of the widget.
      def set_background_color(color)
        return if color.nil? || color == ''

        junk1 = []
        junk2 = []

        # Convert the value of the environment variable to a chtype
        holder = Slithernix::Cdk.char_to_chtype(color, junk1, junk2)

        # Set the widget's background color
        self.SetBackAttrObj(holder[0])
      end

      # Set the widget's title.
      def set_title(title, box_width)
        if title
          temp = title.split("\n")
          @title_lines = temp.size

          if box_width >= 0
            max_width = 0
            temp.each do |line|
              len = []
              align = []
              Slithernix::Cdk.char_to_chtype(line, len, align)
              max_width = [len[0], max_width].max
            end
            box_width = [box_width, max_width + (2 * @border_size)].max
          else
            box_width = -(box_width - 1)
          end

          # For each line in the title convert from string to chtype array
          title_width = box_width - (2 * @border_size)
          @title = []
          @title_pos = []
          @title_len = []
          (0...@title_lines).each do |x|
            len_x = []
            pos_x = []
            @title << Slithernix::Cdk.char_to_chtype(temp[x], len_x, pos_x)
            @title_len.concat(len_x)
            @title_pos << Slithernix::Cdk.justify_string(
              title_width,
              len_x[0],
              pos_x[0],
            )
          end
        end

        box_width
      end

      # Draw the widget's title
      def draw_title(_win)
        (0...@title_lines).each do |x|
          Draw.write_chtype(
            @win,
            @title_pos[x] + @border_size,
            x + @border_size,
            @title[x],
            Slithernix::Cdk::HORIZONTAL,
            0,
            @title_len[x],
          )
        end
      end

      # Remove storage for the widget's title.
      def clean_title
        @title_lines = String.new
      end

      # Set data for preprocessing
      def set_pre_process(fn, data)
        @pre_process_func = fn
        @pre_process_data = data
      end

      # Set data for postprocessing
      def set_post_process(fn, data)
        @post_process_func = fn
        @post_process_data = data
      end

      # Set the widget's exit-type based on the input.
      # The .exitType field should have been part of the CDKOBJS struct, but it
      # is used too pervasively in older applications to move (yet).
      def set_exit_type(ch)
        case ch
        when Curses::Error
          @exit_type = :ERROR
        when Slithernix::Cdk::KEY_ESC
          @exit_type = :ESCAPE_HIT
        when Slithernix::Cdk::KEY_TAB, Curses::KEY_ENTER, Slithernix::Cdk::KEY_RETURN
          @exit_type = :NORMAL
        when 0
          @exit_type = :EARLY_EXIT
        end
      end

      def is_valid_widget?
        result = false
        if Slithernix::Cdk::ALL_OBJECTS.include?(self)
          result = valid_widget_type(widget_type)
        end
        result
      end

      def getc
        cdktype = widget_type
        test = is_bindable_object?(cdktype)
        result = @input_window.getch

        if result.ord >= 0 && !test.nil? && test.binding_list.include?(result) &&
           test.binding_list[result][0] == :getc
          result = test.binding_list[result][1]
        elsif test.nil? || !test.binding_list.include?(result) ||
              test.binding_list[result][0].nil?
          case result
          when "\r", "\n"
            result = Curses::KEY_ENTER
          when "\t"
            result = Slithernix::Cdk::KEY_TAB
          when Slithernix::Cdk::DELETE
            result = Curses::KEY_DC
          when "\b"
            result = Curses::KEY_BACKSPACE
          when Slithernix::Cdk::BEGOFLINE
            result = Curses::KEY_HOME
          when Slithernix::Cdk::ENDOFLINE
            result = Curses::KEY_END
          when Slithernix::Cdk::FORCHAR
            result = Curses::KEY_RIGHT
          when Slithernix::Cdk::BACKCHAR
            result = Curses::KEY_LEFT
          when Slithernix::Cdk::NEXT
            result = Slithernix::Cdk::KEY_TAB
          when Slithernix::Cdk::PREV
            result = Curses::KEY_BTAB
          end
        end

        result
      end

      def getch(function_key)
        key = getc
        function_key << (key.ord >= Curses::KEY_MIN && key.ord <= Curses::KEY_MAX)
        key
      end

      # This is one of many methods whose purpose I really don't get. Look
      # into removal. -- snake 2024
      def is_bindable_object?(_cdktype)
        return @entry_field if %i[FSelect AlphaList].include?(widget_type)

        # if cdktype != widget_type
        #  nil
        # elsif %i[FSelect AlphaList].include?(widget_type)
        #  @entry_field
        # else
        #  self
        # end
        self
      end

      def bind(type, key, function, data)
        widget = is_bindable_object?(type)
        return unless key.ord < Curses::KEY_MAX && widget

        widget.binding_list[key] = [function, data] if key.ord != 0
      end

      def unbind(type, key)
        widget = is_bindable_object?(type)
        widget&.binding_list&.delete(key)
      end

      def clean_bindings(type)
        widget = is_bindable_object?(type)
        widget.binding_list.clear if widget&.binding_list
      end

      # This checks to see if the binding for the key exists:
      # If it does then it runs the command and returns its value, normally true
      # If it doesn't it returns a false.  This way we can 'overwrite' coded
      # bindings.
      def check_bind(type, key)
        widg = is_bindable_object?(type)
        if widg&.binding_list&.include?(key)
          function = widg.binding_list[key][0]
          data = widg.binding_list[key][1]

          return data if function == :getc

          return function.call(type, widg, data, key)

        end
        false
      end

      # This checks to see if the binding for the key exists.
      def does_bind_exist?(type, key)
        result = false
        widg = is_bindable_object?(type)
        result = widg.binding_list.include?(key) unless widg.nil?

        result
      end

      # This allows the user to use the cursor keys to adjust the
      # postion of the widget.
      def position(win)
        parent = @screen.window
        orig_x = win.begx
        orig_y = win.begy
        beg_x = parent.begx
        beg_y = parent.begy
        end_x = beg_x + @screen.window.maxx
        end_y = beg_y + @screen.window.maxy

        # Let them move the widget around until they hit return.
        until [Slithernix::Cdk::KEY_RETURN, Curses::KEY_ENTER].include?(
          key = getch([])
        )
          case key
          when Curses::KEY_UP, '8'
            if win.begy > beg_y
              move(0, -1, true, true)
            else
              Slithernix::Cdk.beep
            end
          when Curses::KEY_DOWN, '2'
            if (win.begy + win.maxy) < end_y
              move(0, 1, true, true)
            else
              Slithernix::Cdk.beep
            end
          when Curses::KEY_LEFT, '4'
            if win.begx > beg_x
              move(-1, 0, true, true)
            else
              Slithernix::Cdk.beep
            end
          when Curses::KEY_RIGHT, '6'
            if (win.begx + win.maxx) < end_x
              move(1, 0, true, true)
            else
              Slithernix::Cdk.beep
            end
          when '7'
            if win.begy > beg_y && win.begx > beg_x
              move(-1, -1, true, true)
            else
              Slithernix::Cdk.beep
            end
          when '9'
            if (win.begx + win.maxx) < end_x && win.begy > beg_y
              move(1, -1, true, true)
            else
              Slithernix::Cdk.beep
            end
          when '1'
            if win.begx > beg_x && (win.begy + win.maxy) < end_y
              move(-1, 1, true, true)
            else
              Slithernix::Cdk.beep
            end
          when '3'
            if (win.begx + win.maxx) < end_x &&
               (win.begy + win.maxy) < end_y
              move(1, 1, true, true)
            else
              Slithernix::Cdk.beep
            end
          when '5'
            move(Slithernix::Cdk::CENTER, Slithernix::Cdk::CENTER, false, true)
          when 't'
            move(win.begx, Slithernix::Cdk::TOP, false, true)
          when 'b'
            move(win.begx, Slithernix::Cdk::BOTTOM, false, true)
          when 'l'
            move(Slithernix::Cdk::LEFT, win.begy, false, true)
          when 'r'
            move(Slithernix::Cdk::RIGHT, win.begy, false, true)
          when 'c'
            move(Slithernix::Cdk::CENTER, win.begy, false, true)
          when 'C'
            move(win.begx, Slithernix::Cdk::CENTER, false, true)
          when Slithernix::Cdk::REFRESH
            @screen.erase
            @screen.refresh
          when Slithernix::Cdk::KEY_ESC
            move(orig_x, orig_y, false, true)
          else
            Slithernix::Cdk.beep
          end
        end
      end
    end
  end
end
