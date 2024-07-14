# frozen_string_literal: true

require 'curses'
require 'pathname'
require 'pry-remote'
require_relative 'cdk/monkey_patches'

require_relative 'cdk/draw'
require_relative 'cdk/display'
require_relative 'cdk/traverse'

require_relative 'cdk/screen'
require_relative 'cdk/widget'

Pathname.glob("#{File.dirname(__FILE__)}/cdk/widget/*.rb").each do |f|
  require f
end

Curses.ESCDELAY = 0

module Slithernix
  # Top-level module for Curses Development Kit
  module Cdk
    @all_screens = []
    @all_objects = []

    @curses_attr_map = {
      'B' => Curses::A_BOLD,
      'D' => Curses::A_DIM,
      'K' => Curses::A_BLINK,
      'R' => Curses::A_REVERSE,
      'S' => Curses::A_STANDOUT,
      'U' => Curses::A_UNDERLINE,
    }.freeze

    class << self
      attr_accessor :all_screens, :all_objects
      attr_reader :curses_attr_map

      def ctrl(key)
        key.ord & 0x1f
      end
    end

    CDK_PATHMAX = 256

    L_MARKER = '<'
    R_MARKER = '>'

    LEFT = 9000
    RIGHT = 9001
    CENTER = 9002
    TOP = 9003
    BOTTOM = 9004
    HORIZONTAL = 9005
    VERTICAL = 9006
    FULL = 9007

    NONE = 0
    ROW = 1
    COL = 2

    MAX_BINDINGS = 300
    MAX_ITEMS = 2000
    MAX_BUTTONS = 200

    BACKCHAR = ctrl('B')
    BEGOFLINE = ctrl('A')
    COPY = ctrl('Y')
    CUT = ctrl('X')
    DELETE = "\177".ord
    ENDOFLINE = ctrl('E')
    ERASE = ctrl('U')
    FORCHAR = ctrl('F')
    KEY_ESC = "\033".ord
    KEY_RETURN = "\012".ord
    KEY_TAB = "\t".ord
    NEXT = ctrl('N')
    PASTE = ctrl('V')
    PREV = ctrl('P')
    REFRESH = ctrl('L')
    TRANSPOSE = ctrl('T')

    # ACS constants seem to have been removed from ruby curses, putting
    # them here. note that this is garbage and likely to break all over
    # the place.
    ACS_CONSTANTS = {
      block: 0x30,
      board: 0x65,
      btee: 0x76,
      bullet: 0x7e,
      ckboard: 0x61,
      darrow: 0x2e,
      degree: 0x66,
      diamond: 0x60,
      gequal: 0x7a,
      hline: 0x71,
      lantern: 0x69,
      larrow: 0x2c,
      lequal: 0x79,
      llcorner: 0x6d,
      lrcorner: 0x6a,
      ltee: 0x74,
      nequal: 0x7c,
      pi: 0x7b,
      plminus: 0x67,
      plus: 0x6e,
      rarrow: 0x2b,
      rtee: 0x75,
      s1: 0x6f,
      s3: 0x70,
      s5: 0x71,
      s7: 0x72,
      s9: 0x73,
      sterling: 0x7d,
      ttee: 0x77,
      uarrow: 0x2d,
      ulcorner: 0x6c,
      urcorner: 0x6b,
      vline: 0x78
    }.freeze

    ACS_CONSTANTS.each do |name, value|
      const_set("ACS_#{name.upcase}", value | Curses::A_ALTCHARSET)
    end

    class << self
      def beep
        Curses.beep
        $stdout.flush
      end

      def clean_char(str, len, char)
        str << (char * len)
      end

      def clean_chtype(str, len, char)
        str.concat(char * len)
      end

      # This takes an x and y position and realigns the values iff they sent in
      # values like CENTER, LEFT, RIGHT
      #
      # window is an Curses::Window
      # xpos, ypos is an array with exactly one value, an integer
      # box_width, box_height is an integer
      def alignxy(window, xpos, ypos, box_width, box_height)
        align_dimension(window, xpos, box_width, :x)
        align_dimension(window, ypos, box_height, :y)
      end

      def align_dimension(window, pos, box_size, dimension)
        first, last = get_window_bounds(window, dimension)
        gap = calculate_gap(last, box_size)
        last = first + gap

        pos[0] = case pos[0]
                 when LEFT, TOP then first
                 when RIGHT, BOTTOM then first + gap
                 when CENTER then first + (gap / 2)
                 else constrain_position(pos[0], first, last)
                 end
      end

      def get_window_bounds(window, dimension)
        if dimension == :x
          [window.begx, window.maxx]
        else
          [window.begy, window.maxy]
        end
      end

      def calculate_gap(last, box_size)
        gap = last - box_size
        gap.negative? ? 0 : gap
      end

      def constrain_position(pos, first, last)
        pos.clamp(first, last)
      end

      # This takes a string, a field width, and a justification type
      # and returns the adjustment to make, to fill the justification
      # requirement
      def justify_string(box_width, mesg_length, justify)
        return 0 if mesg_length >= box_width

        case justify
        when LEFT then 0
        when RIGHT then box_width - mesg_length
        when CENTER then (box_width - mesg_length) / 2
        else justify
        end
      end

      # This reads a file and sticks it into the list provided.
      def read_file(filename, arr)
        lines = File.readlines(filename, chomp: true)
        arr.concat(lines)
        arr.size
      rescue StandardError
        -1
      end

      def encode_attribute(string, from, mask)
        mask[0] = curses_attr_map[string[from + 1]] || 0
        return from + 1 if mask[0] != 0

        encode_color_pair(string, from, mask)
      end

      def encode_color_pair(string, from, mask)
        return from unless digit?(string[from + 1])

        match = string[(from + 1)..].match(/\d+/)
        return from unless match

        mask[0] = Curses.color_pair(match[0].to_i)
        from + match[0].length
      end

      # The reverse of encode_attribute
      # Well, almost.  If attributes such as bold and underline are combined in
      # the same string, we do not necessarily reconstruct them in the same
      # order. Also, alignment markers and tabs are lost.

      def decode_attribute(string, from, oldattr, newattr)
        result = string.nil? ? '' : string
        base_len = result.size
        tmpattr = oldattr & Curses::A_ATTRIBUTES

        newattr &= Curses::A_ATTRIBUTES
        if tmpattr != newattr
          while tmpattr != newattr
            found = false
            curses_attr_map.each_key do |key|
              next unless (curses_attr_map[key] & tmpattr) != (curses_attr_map[key] & newattr)

              found = true
              result << Slithernix::Cdk::L_MARKER
              if (curses_attr_map[key] & tmpattr).nonzero?
                result << '!'
                tmpattr = tmpattr.clear_bits(curses_attr_map[key])
              else
                result << '/'
                tmpattr |= curses_attr_map[key]
              end
              result << key
              break
            end

            if self.needs_color_change?(tmpattr, newattr)
              oldpair = Curses.pair_number(tmpattr)
              newpair = Curses.pair_number(newattr)
              unless found
                found = true
                result << Slithernix::Cdk::L_MARKER
              end
              if newpair.zero?
                result << '!'
                result << oldpair.to_s
              else
                result << '/'
                result << newpair.to_s
              end
              tmpattr = tmpattr.clear_bits(Curses::A_COLOR)
              newattr = newattr.clear_bits(Curses::A_COLOR)
            end

            break unless found

            result << Slithernix::Cdk::R_MARKER
          end
        end

        from + result.size - base_len
      end

      # This function takes a string, full of format markers and translates
      # them into a chtype array.  This is better suited to curses because
      # curses uses chtype almost exclusively
      def char_to_chtype(string, to, align)
        to << 0
        align << LEFT
        result = []

        if string.size.positive?
          used = 0

          # The original code makes two passes since it has to pre-allocate space
          # but we should be able to make do with one since we can dynamically
          # size it.
          adjust = 0
          attrib = Curses::A_NORMAL
          last_char = 0
          start = 0
          used = 0
          x = 3

          # Look for an alignment marker.
          if string[0] == L_MARKER
            if string[1] == 'C' && string[2] == R_MARKER
              align[0] = CENTER
              start = 3
            elsif string[1] == 'R' && string[2] == R_MARKER
              align[0] = RIGHT
              start = 3
            elsif string[1] == 'L' && string[2] == R_MARKER
              start = 3
            elsif string[1] == 'B' && string[2] == '='
              # Set the item index value in the string.
              result = [' '.ord, ' '.ord, ' '.ord]

              # Pull out the bullet marker.
              while (x < string.size) && (string[x] != R_MARKER)
                result << (string[x].ord | Curses::A_BOLD)
                x += 1
              end
              adjust = 1

              # Set the alignment variables
              start = x
              used = x
            elsif string[1] == 'I' && string[2] == '='
              from = 3
              x = 0

              while from < string.size && string[from] != Curses.R_MARKER
                if digit?(string[from])
                  adjust = (adjust * 10) + string[from].to_i
                  x += 1
                end
                from += 1
              end

              start = x + 4
            end
          end

          while adjust.positive?
            adjust -= 1
            result << ' '
            used += 1
          end

          # Set the format marker boolean to false
          inside_marker = false

          # Start parsing the character string.
          from = start
          while from < string.size
            # Are we inside a format marker?
            if inside_marker
              case string[from]
              when R_MARKER
                inside_marker = false
              when '#'
                last_char = 0
                case string[from + 2]
                when 'L'
                  case string[from + 1]
                  when 'L'
                    last_char = Slithernix::Cdk::ACS_LLCORNER
                  when 'U'
                    last_char = Slithernix::Cdk::ACS_ULCORNER
                  when 'H'
                    last_char = Slithernix::Cdk::ACS_HLINE
                  when 'V'
                    last_char = Slithernix::Cdk::ACS_VLINE
                  when 'P'
                    last_char = Slithernix::Cdk::ACS_PLUS
                  end
                when 'R'
                  case string[from + 1]
                  when 'L'
                    last_char = Slithernix::Cdk::ACS_LRCORNER
                  when 'U'
                    last_char = Slithernix::Cdk::ACS_URCORNER
                  end
                when 'T'
                  case string[from + 1]
                  when 'T'
                    last_char = Slithernix::Cdk::ACS_TTEE
                  when 'R'
                    last_char = Slithernix::Cdk::ACS_RTEE
                  when 'L'
                    last_char = Slithernix::Cdk::ACS_LTEE
                  when 'B'
                    last_char = Slithernix::Cdk::ACS_BTEE
                  end
                when 'A'
                  case string[from + 1]
                  when 'L'
                    last_char = Slithernix::Cdk::ACS_LARROW
                  when 'R'
                    last_char = Slithernix::Cdk::ACS_RARROW
                  when 'U'
                    last_char = Slithernix::Cdk::ACS_UARROW
                  when 'D'
                    last_char = Slithernix::Cdk::ACS_DARROW
                  end
                else
                  case [string[from + 1], string[from + 2]]
                  when %w[D I]
                    last_char = Slithernix::Cdk::ACS_DIAMOND
                  when %w[C B]
                    last_char = Slithernix::Cdk::ACS_CKBOARD
                  when %w[D G]
                    last_char = Slithernix::Cdk::ACS_DEGREE
                  when %w[P M]
                    last_char = Slithernix::Cdk::ACS_PLMINUS
                  when %w[B U]
                    last_char = Slithernix::Cdk::ACS_BULLET
                  when %w[S 1]
                    last_char = Slithernix::Cdk::ACS_S1
                  when %w[S 9]
                    last_char = Slithernix::Cdk::ACS_S9
                  end
                end

                if last_char.nonzero?
                  adjust = 1
                  from += 2

                  if string[from + 1] == '('
                    # check for a possible numeric modifier
                    from += 2
                    adjust = 0

                    while from < string.size && string[from] != ')'
                      if digit?(string[from])
                        adjust = (adjust * 10) + string[from].to_i
                      end
                      from += 1
                    end
                  end
                end
                (0...adjust).each do |_x|
                  result << (last_char | attrib)
                  used += 1
                end
              when '/'
                mask = []
                from = encode_attribute(string, from, mask)
                attrib |= mask[0]
              when '!'
                mask = []
                from = encode_attribute(string, from, mask)
                attrib = attrib.clear_bits(mask[0])
              end
            elsif string[from] == L_MARKER &&
                  ['/', '!', '#'].include?(string[from + 1])
              inside_marker = true
            elsif string[from] == '\\' && string[from + 1] == L_MARKER
              from += 1
              result << (string[from].ord | attrib)
              used += 1
              from += 1
            elsif string[from] == "\t"
              loop do
                result << ' '
                used += 1
                break unless (used & 7).nonzero?
              end
            else
              result << (string[from].ord | attrib)
              used += 1
            end
            from += 1
          end

          result << attrib if result.empty?
          to[0] = used
        else
          result = []
        end
        result
      end

      # Compare a regular string to a chtype string
      def compare_string_to_chtype_string(str, chstr)
        i = 0
        r = 0

        if str.nil? && chstr.nil?
          return 0
        elsif str.nil?
          return 1
        elsif chstr.nil?
          return -1
        end

        while i < str.size && i < chstr.size
          if str[r].ord < chstr[r]
            return -1
          elsif str[r].ord > chstr[r]
            return 1
          end

          i += 1
        end

        if str.size < chstr.size
          -1
        elsif str.size > chstr.size
          1
        else
          0
        end
      end

      def chtype_to_char(chtype)
        (chtype.ord & 255).chr
      end

      # This returns a string from a chtype array
      # Formatting codes are omitted.
      def chtype_string_to_unformatted_string(string)
        newstring = String.new

        string&.each do |char|
          newstring << chtype_to_char(char)
        end

        newstring
      end

      # This returns a string from a chtype array
      # Formatting codes are embedded
      def chtype_string_to_formatted_string(string)
        newstring = String.new
        unless string.nil?
          need = 0
          (0...string.size).each do |x|
            need = decode_attribute(
              newstring,
              need,
              x.positive? ? string[x - 1] : 0,
              string[x],
            )
            newstring << string[x]
          end
        end

        newstring
      end

      # This returns the length of the integer.
      #
      # Currently a wrapper maintained for easy of porting.
      # TODO remove this useless method
      def intlen(value)
        value.to_str.size
      end

      # This opens the current directory and reads the contents.
      # This method is absolute dogshit, should just return the list.
      # I hate the mutation of the second argument rather than the return.
      # TODO: fix --snake 2024
      def get_directory_contents(directory, list)
        # Open the directory.
        Dir.foreach(directory) do |filename|
          next if filename == '.'

          list << filename
        end

        list.sort!
        list.size
      end

      # This looks for a subset of a word in the given list
      # TODO no way this thing is necessary as it is
      def search_list(list, list_size, pattern)
        index = -1

        if pattern.size.positive?
          (0...list_size).each do |x|
            len = [list[x].size, pattern.size].min
            ret = (list[x][0...len] <=> pattern)

            # If 'ret' is less than 0 then the current word is alphabetically
            # less than the provided word.  At this point we will set the index
            # to the current position.  If 'ret' is greater than 0, then the
            # current word is alphabetically greater than the given word. We
            # should return with index, which might contain the last best match.
            # If they are equal then we've found it.
            if ret.negative?
              index = ret
            else
              index = x if ret.zero?
              break
            end
          end
        end
        index
      end

      # This function checks to see if a link has been requested
      def check_for_link(line, filename)
        f_pos = 0
        x = 3
        return -1 if line.nil?

        # Strip out the filename.
        if line[0] == L_MARKER && line[1] == 'F' && line[2] == '='
          while x < line.size
            break if line[x] == R_MARKER

            if f_pos < CDK_PATHMAX
              filename << line[x]
              f_pos += 1
            end
            x += 1
          end
        end
        f_pos != 0
      end

      # Returns the filename portion of the given pathname, i.e. after the last
      # slash
      # For now this function is just a wrapper for File.basename kept for ease
      # of porting and will be completely replaced in the future
      def basename(pathname)
        File.basename(pathname)
      end

      # Returns the directory for the given pathname, i.e. the part before the
      # last slash
      # For now this function is just a wrapper for File.dirname kept for ease
      # of porting and will be completely replaced in the future
      def dirname(pathname)
        File.dirname(pathname)
      end

      # If the dimension is a negative value, the dimension will be the full
      # height/width of the parent window - the value of the dimension.
      # Otherwise, the dimension will be the given value.
      def set_widget_dimension(parent_dim, proposed_dim, adjustment)
        # If the user passed in FULL, return the parents size
        if [FULL, 0].include?(proposed_dim)
          parent_dim
        elsif proposed_dim >= 0
          # if they gave a positive value, return it

          if proposed_dim >= parent_dim
            parent_dim
          else
            proposed_dim + adjustment
          end
        elsif (parent_dim + proposed_dim).negative?
          # if they gave a negative value then return the dimension
          # of the parent plus the value given
          #
          parent_dim
        else
          parent_dim + proposed_dim
        end
      end

      # This safely erases a given window
      def erase_curses_window(window)
        return if window.nil?

        window.erase
        window.refresh
      end

      # This safely deletes a given window.
      def delete_curses_window(window)
        return if window.nil?

        erase_curses_window(window)
        window.close
      end

      # This moves a given window (if we're able to set the window's beginning).
      # We do not use mvwin(), because it does not (usually) move subwindows.
      #
      # This just didn't work as it was. Maybe this mvwin() comment is no longer
      # accurate but for now, leaving in the usage of window.move. --snake 2024
      def move_curses_window(window, xdiff, ydiff)
        return if window.nil?

        xpos = window.begx + xdiff
        ypos = window.begy + ydiff

        old_window = window
        window.move(ypos, xpos)
        begin
          # window = Curses::Window.new(
          # old_window.begy,
          # old_window.begx,
          # ypos,
          # xpos
          # )
          old_window.erase
          # window
        rescue StandardError
          beep
        end
      end

      def digit?(character)
        !character.match(/^[[:digit:]]$/).nil?
      end

      def alpha?(character)
        !character.match(/^[[:alpha:]]$/).nil?
      end

      def is_char?(c)
        c.ord >= 0 && c.ord < Curses::KEY_MIN
      end

      def key_f(n)
        264 + n
      end

      # TODO move/remove this, dummy method
      def version
        "0.0.1"
      end

      def get_string(screen, title, label, init_value)
        # Create the widget.
        widget = Slithernix::Cdk::Entry.new(
          screen,
          Slithernix::Cdk::CENTER,
          Slithernix::Cdk::CENTER,
          title,
          label,
          Curses::A_NORMAL,
          '.',
          :MIXED,
          40,
          0,
          5000,
          true,
          false,
        )

        # Set the default value.
        widget.set_value(init_value)

        # Get the string.
        widget.activate([])

        # Make sure they exited normally.
        if widget.exit_type != :NORMAL
          widget.destroy
          return nil
        end

        # Return a copy of the string typed in.
        value = entry.get_value.clone
        widget.destroy
        value
      end

      # This allows a person to select a file.
      def select_file(screen, title)
        # Create the file selector.
        fselect = Slithernix::Cdk::FSelect.new(
          screen,
          Slithernix::Cdk::CENTER,
          Slithernix::Cdk::CENTER,
          -4,
          -20,
          title,
          'File: ',
          Curses::A_NORMAL,
          '_',
          Curses::A_REVERSE,
          '</5>',
          '</48>',
          '</N>',
          '</N>',
          true,
          false,
        )

        filename = fselect.activate([])

        if fselect.exit_type != :NORMAL
          fselect.destroy
          screen.refresh
          return nil
        end

        fselect.destroy
        screen.refresh
        filename
      end

      # This returns a selected value in a list
      def get_list_index(screen, title, list, list_size, numbers)
        height = 10
        width = -1

        # Determine the height of the list.
        if list_size < 10
          height = list_size + (title.empty? ? 2 : 3)
        end

        # Determine the width of the list.
        list.each do |item|
          width = [width, item.size + 10].max
        end

        width = [width, title.size].max
        width += 5

        # Create the scrolling list.
        scrollp = Slithernix::Cdk::Scroll.new(
          screen,
          Slithernix::Cdk::CENTER,
          Slithernix::Cdk::CENTER,
          Slithernix::Cdk::RIGHT,
          height,
          width,
          title,
          list,
          list_size,
          numbers,
          Curses::A_REVERSE,
          true,
          false,
        )

        # Check if we made the lsit.
        if scrollp.nil?
          screen.refresh
          return -1
        end

        # Let the user play.
        selected = scrollp.activate([])

        # Check how they exited.
        selected = -1 if scrollp.exit_type != :NORMAL

        # Clean up.
        scrollp.destroy
        screen.refresh
        selected
      end

      def view_info(screen, title, info, count, buttons, button_count, interpret)
        # Create the file viewer to view the file selected.
        viewer = Slithernix::Cdk::Widget::Viewer.new(
          screen,
          Slithernix::Cdk::CENTER,
          Slithernix::Cdk::CENTER,
          -6,
          -16,
          buttons,
          button_count,
          Curses::A_REVERSE,
          true,
          true,
        )

        # Set up the viewer title, and the contents to the widget.
        viewer.set(title, info, count, Curses::A_REVERSE, interpret, true, true)

        selected = viewer.activate([])

        if viewer.exit_type != :NORMAL
          viewer.destroy
          return -1
        end

        viewer.destroy
        selected
      end

      def view_file(screen, title, filename, buttons, button_count)
        info = []

        # Open the file and read the contents.
        lines = read_file(filename, info)

        # If we couldn't read the file, return an error.
        if lines == -1
          lines
        else
          view_info(
            screen,
            title,
            info,
            lines,
            buttons,
            button_count,
            true
          )
        end
      end

      def needs_color_change?(tmpattr, newattr)
        return false unless Curses.has_colors?

        (tmpattr & Curses::A_COLOR) != (newattr & Curses::A_COLOR)
      end
    end
  end
end
