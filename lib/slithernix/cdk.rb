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

trace = TracePoint.new(:call) do |tp|
  File.open('/tmp/execution_trace.log', 'a') do |f|
    f.puts "Called method '#{tp.method_id}' at #{tp.path}:#{tp.lineno}"
  end
end

trace.enable

module Slithernix
  module Cdk
    # some useful global values
    # but these aren't global variables? -- snake 2024

    def self.CTRL(c)
      c.ord & 0x1f
    end

    VERSION_MAJOR = 0
    VERSION_MINOR = 0
    VERSION_PATCH = 1

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

    REFRESH = self.CTRL('L')
    PASTE = self.CTRL('V')
    COPY = self.CTRL('Y')
    ERASE = self.CTRL('U')
    CUT = self.CTRL('X')
    BEGOFLINE = self.CTRL('A')
    ENDOFLINE = self.CTRL('E')
    BACKCHAR = self.CTRL('B')
    FORCHAR = self.CTRL('F')
    TRANSPOSE = self.CTRL('T')
    NEXT = self.CTRL('N')
    PREV = self.CTRL('P')
    DELETE = "\177".ord
    KEY_ESC = "\033".ord
    KEY_RETURN = "\012".ord
    KEY_TAB = "\t".ord

    ALL_SCREENS = []
    ALL_OBJECTS = []

    # ACS constants have been removed from ruby curses, putting them here
    # note that this is garbage and likely to break all over the place.
    ACS_BLOCK     = 0x30 | Curses::A_ALTCHARSET
    ACS_BOARD     = 0x65 | Curses::A_ALTCHARSET
    ACS_BTEE      = 0x76 | Curses::A_ALTCHARSET
    ACS_BULLET    = 0x7e | Curses::A_ALTCHARSET
    ACS_CKBOARD   = 0x61 | Curses::A_ALTCHARSET
    ACS_DARROW    = 0x2e | Curses::A_ALTCHARSET
    ACS_DEGREE    = 0x66 | Curses::A_ALTCHARSET
    ACS_DIAMOND   = 0x60 | Curses::A_ALTCHARSET
    ACS_GEQUAL    = 0x7a | Curses::A_ALTCHARSET
    ACS_HLINE     = 0x71 | Curses::A_ALTCHARSET
    ACS_LANTERN   = 0x69 | Curses::A_ALTCHARSET
    ACS_LARROW    = 0x2c | Curses::A_ALTCHARSET
    ACS_LEQUAL    = 0x79 | Curses::A_ALTCHARSET
    ACS_LLCORNER  = 0x6d | Curses::A_ALTCHARSET
    ACS_LRCORNER  = 0x6a | Curses::A_ALTCHARSET
    ACS_LTEE      = 0x74 | Curses::A_ALTCHARSET
    ACS_NEQUAL    = 0x7c | Curses::A_ALTCHARSET
    ACS_PI        = 0x7b | Curses::A_ALTCHARSET
    ACS_PLMINUS   = 0x67 | Curses::A_ALTCHARSET
    ACS_PLUS      = 0x6e | Curses::A_ALTCHARSET
    ACS_RARROW    = 0x2b | Curses::A_ALTCHARSET
    ACS_RTEE      = 0x75 | Curses::A_ALTCHARSET
    ACS_S1        = 0x6f | Curses::A_ALTCHARSET
    ACS_S3        = 0x70 | Curses::A_ALTCHARSET
    ACS_S5        = 0x71 | Curses::A_ALTCHARSET
    ACS_S7        = 0x72 | Curses::A_ALTCHARSET
    ACS_S9        = 0x73 | Curses::A_ALTCHARSET
    ACS_STERLING  = 0x7d | Curses::A_ALTCHARSET
    ACS_TTEE      = 0x77 | Curses::A_ALTCHARSET
    ACS_UARROW    = 0x2d | Curses::A_ALTCHARSET
    ACS_ULCORNER  = 0x6c | Curses::A_ALTCHARSET
    ACS_URCORNER  = 0x6b | Curses::A_ALTCHARSET
    ACS_VLINE     = 0x78 | Curses::A_ALTCHARSET

    # This beeps then flushes the stdout stream
    def self.Beep
      Curses.beep
      $stdout.flush
    end

    # This sets a blank string to be len of the given characer.
    def self.cleanChar(s, len, character)
      s << character * len
    end

    def self.cleanChtype(s, len, character)
      s.concat(character * len)
    end

    # This takes an x and y position and realigns the values iff they sent in
    # values like CENTER, LEFT, RIGHT
    #
    # window is an Curses::WINDOW widget
    # xpos, ypos is an array with exactly one value, an integer
    # box_width, box_height is an integer
    def self.alignxy (window, xpos, ypos, box_width, box_height)
      first = window.begx
      last = window.maxx
      if (gap = (last - box_width)) < 0
        gap = 0
      end
      last = first + gap

      case xpos[0]
      when LEFT
        xpos[0] = first
      when RIGHT
        xpos[0] = first + gap
      when CENTER
        xpos[0] = first + (gap / 2)
      else
        if xpos[0] > last
          xpos[0] = last
        elsif xpos[0] < first
          xpos[0] = first
        end
      end

      first = window.begy
      last = window.maxy
      if (gap = (last - box_height)) < 0
        gap = 0
      end
      last = first + gap

      case ypos[0]
      when TOP
        ypos[0] = first
      when BOTTOM
        ypos[0] = first + gap
      when CENTER
        ypos[0] = first + (gap / 2)
      else
        if ypos[0] > last
          ypos[0] = last
        elsif ypos[0] < first
          ypos[0] = first
        end
      end
    end

    # This takes a string, a field width, and a justification type
    # and returns the adjustment to make, to fill the justification
    # requirement
    def self.justifyString (box_width, mesg_length, justify)

      # make sure the message isn't longer than the width
      # if it is, return 0
      if mesg_length >= box_width
        return 0
      end

      # try to justify the message
      case justify
      when LEFT
        0
      when RIGHT
        box_width - mesg_length
      when CENTER
        (box_width - mesg_length) / 2
      else
        justify
      end
    end

    # This reads a file and sticks it into the list provided.
    def self.readFile(filename, array)
      begin
        fd = File.new(filename, "r")
      rescue
        return -1
      end

      lines = fd.readlines.map do |line|
        if line.size > 0 && line[-1] == "\n"
          line[0...-1]
        else
          line
        end
      end
      array.concat(lines)
      fd.close
      array.size
    end

    def self.encodeAttribute (string, from, mask)
      mask << 0
      case string[from + 1]
        when 'B' then mask[0] = Curses::A_BOLD
        when 'D' then mask[0] = Curses::A_DIM
        when 'K' then mask[0] = Curses::A_BLINK
        when 'R' then mask[0] = Curses::A_REVERSE
        when 'S' then mask[0] = Curses::A_STANDOUT
        when 'U' then mask[0] = Curses::A_UNDERLINE
      end

      if mask[0] != 0
        from += 1
      elsif self.digit?(string[from+1]) and self.digit?(string[from + 2])
        mask[0] = Curses::A_BOLD

        if Curses.has_colors?
          # XXX: Only checks if terminal has colours not if colours are started
          pair = string[from + 1..from + 2].to_i
          mask[0] = Curses.color_pair(pair)
        end

        from += 2
      elsif self.digit?(string[from + 1])
        if Curses.has_colors?
          # XXX: Only checks if terminal has colours not if colours are started
          pair = string[from + 1].to_i
          mask[0] = Curses.color_pair(pair)
        else
          mask[0] = Curses.A_BOLD
        end

        from += 1
      end

      return from
    end

    # The reverse of encodeAttribute
    # Well, almost.  If attributes such as bold and underline are combined in the
    # same string, we do not necessarily reconstruct them in the same order.
    # Also, alignment markers and tabs are lost.

    def self.decodeAttribute (string, from, oldattr, newattr)
      table = {
        'B' => Curses::A_BOLD,
        'D' => Curses::A_DIM,
        'K' => Curses::A_BLINK,
        'R' => Curses::A_REVERSE,
        'S' => Curses::A_STANDOUT,
        'U' => Curses::A_UNDERLINE
      }

      result = if string.nil? then '' else string end
      base_len = result.size
      tmpattr = oldattr & Curses::A_ATTRIBUTES

      newattr &= Curses::A_ATTRIBUTES
      if tmpattr != newattr
        while tmpattr != newattr
          found = false
          table.keys.each do |key|
            if (table[key] & tmpattr) != (table[key] & newattr)
              found = true
              result << Slithernix::Cdk::L_MARKER
              if (table[key] & tmpattr).nonzero?
                result << '!'
                tmpattr &= ~(table[key])
              else
                result << '/'
                tmpattr |= table[key]
              end
              result << key
              break
            end
          end
          # XXX: Only checks if terminal has colours not if colours are started
          if Curses.has_colors?
            if (tmpattr & Curses::A_COLOR) != (newattr & Curses::A_COLOR)
              oldpair = Curses.PAIR_NUMBER(tmpattr)
              newpair = Curses.PAIR_NUMBER(newattr)
              if !found
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
              tmpattr &= ~(Curses::A_COLOR)
              newattr &= ~(Curses::A_COLOR)
            end
          end

          if found
            result << Slithernix::Cdk::R_MARKER
          else
            break
          end
        end
      end

      return from + result.size - base_len
    end

    # This function takes a string, full of format markers and translates
    # them into a chtype array.  This is better suited to curses because
    # curses uses chtype almost exclusively
    def self.char2Chtype (string, to, align)
      to << 0
      align << LEFT
      result = []

      if string.size > 0
        used = 0

        # The original code makes two passes since it has to pre-allocate space but
        # we should be able to make do with one since we can dynamically size it
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
            while x < string.size and string[x] != R_MARKER
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
              if self.digit?(string[from])
                adjust = adjust * 10 + string[from].to_i
                x += 1
              end
              from += 1
            end

            start = x + 4
          end
        end

        while adjust > 0
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
          if !inside_marker
            if string[from] == L_MARKER &&
                ['/', '!', '#'].include?(string[from + 1])
              inside_marker = true
            elsif string[from] == "\\" && string[from + 1] == L_MARKER
              from += 1
              result << (string[from].ord | attrib)
              used += 1
              from += 1
            elsif string[from] == "\t"
              begin
                result << ' '
                used += 1
              end while (used & 7).nonzero?
            else
              result << (string[from].ord | attrib)
              used += 1
            end
          else
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
                when ['D', 'I']
                  last_char = Slithernix::Cdk::ACS_DIAMOND
                when ['C', 'B']
                  last_char = Slithernix::Cdk::ACS_CKBOARD
                when ['D', 'G']
                  last_char = Slithernix::Cdk::ACS_DEGREE
                when ['P', 'M']
                  last_char = Slithernix::Cdk::ACS_PLMINUS
                when ['B', 'U']
                  last_char = Slithernix::Cdk::ACS_BULLET
                when ['S', '1']
                  last_char = Slithernix::Cdk::ACS_S1
                when ['S', '9']
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
                    if self.digit?(string[from])
                      adjust = (adjust * 10) + string[from].to_i
                    end
                    from += 1
                  end
                end
              end
              (0...adjust).each do |x|
                result << (last_char | attrib)
                used += 1
              end
            when '/'
              mask = []
              from = self.encodeAttribute(string, from, mask)
              attrib |= mask[0]
            when '!'
              mask = []
              from = self.encodeAttribute(string, from, mask)
              attrib &= ~(mask[0])
            end
          end
          from += 1
        end

        if result.size == 0
          result << attrib
        end
        to[0] = used
      else
        result = []
      end
      return result
    end

    # Compare a regular string to a chtype string
    def self.cmpStrChstr (str, chstr)
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
        return -1
      elsif str.size > chstr.size
        return 1
      else
        return 0
      end
    end

    def self.CharOf(chtype)
      (chtype.ord & 255).chr
    end

    # This returns a string from a chtype array
    # Formatting codes are omitted.
    def self.chtype2Char(string)
      newstring = ''

      unless string.nil?
        string.each do |char|
          newstring << self.CharOf(char)
        end
      end

      return newstring
    end

    # This returns a string from a chtype array
    # Formatting codes are embedded
    def self.chtype2String(string)
      newstring = ''
      unless string.nil?
        need = 0
        (0...string.size).each do |x|
          need = self.decodeAttribute(newstring, need,
                                     x > 0 ? string[x - 1] : 0, string[x])
          newstring << string[x]
        end
      end

      return newstring
    end

    # This returns the length of the integer.
    #
    # Currently a wrapper maintained for easy of porting.
    def self.intlen (value)
      value.to_str.size
    end

    # This opens the current directory and reads the contents.
    def self.getDirectoryContents(directory, list)
      counter = 0

      # Open the directory.
      Dir.foreach(directory) do |filename|
        next if filename == '.'
        list << filename
      end

      list.sort!
      return list.size
    end

    # This looks for a subset of a word in the given list
    def self.searchList(list, list_size, pattern)
      index = -1

      if pattern.size > 0
        (0...list_size).each do |x|
          len = [list[x].size, pattern.size].min
          ret = (list[x][0...len] <=> pattern)

          # If 'ret' is less than 0 then the current word is alphabetically
          # less than the provided word.  At this point we will set the index
          # to the current position.  If 'ret' is greater than 0, then the
          # current word is alphabetically greater than the given word. We
          # should return with index, which might contain the last best match.
          # If they are equal then we've found it.
          if ret < 0
            index = ret
          else
            if ret == 0
              index = x
            end
            break
          end
        end
      end
      return index
    end

    # This function checks to see if a link has been requested
    def self.checkForLink (line, filename)
      f_pos = 0
      x = 3
      if line.nil?
        return -1
      end

      # Strip out the filename.
      if line[0] == L_MARKER && line[1] == 'F' && line[2] == '='
        while x < line.size
          if line[x] == R_MARKER
            break
          end
          if f_pos < CDK_PATHMAX
            filename << line[x]
            f_pos += 1
          end
          x += 1
        end
      end
      return f_pos != 0
    end

    # Returns the filename portion of the given pathname, i.e. after the last
    # slash
    # For now this function is just a wrapper for File.basename kept for ease of
    # porting and will be completely replaced in the future
    def self.baseName (pathname)
      File.basename(pathname)
    end

    # Returns the directory for the given pathname, i.e. the part before the
    # last slash
    # For now this function is just a wrapper for File.dirname kept for ease of
    # porting and will be completely replaced in the future
    def self.dirName (pathname)
      File.dirname(pathname)
    end

    # If the dimension is a negative value, the dimension will be the full
    # height/width of the parent window - the value of the dimension. Otherwise,
    # the dimension will be the given value.
    def self.setWidgetDimension (parent_dim, proposed_dim, adjustment)
      # If the user passed in FULL, return the parents size
      if proposed_dim == FULL or proposed_dim == 0
        parent_dim
      elsif proposed_dim >= 0
        # if they gave a positive value, return it

        if proposed_dim >= parent_dim
          parent_dim
        else
          proposed_dim + adjustment
        end
      else
        # if they gave a negative value then return the dimension
        # of the parent plus the value given
        #
        if parent_dim + proposed_dim < 0
          parent_dim
        else
          parent_dim + proposed_dim
        end
      end
    end

    # This safely erases a given window
    def self.eraseCursesWindow (window)
      return if window.nil?

      window.erase
      window.refresh
    end

    # This safely deletes a given window.
    def self.deleteCursesWindow (window)
      return if window.nil?

      self.eraseCursesWindow(window)
      window.close
    end

    # This moves a given window (if we're able to set the window's beginning).
    # We do not use mvwin(), because it does not (usually) move subwindows.
    # This just didn't work as it was. 
    def self.moveCursesWindow (window, xdiff, ydiff)
      return if window.nil?

      xpos = window.begx + xdiff
      ypos = window.begy + ydiff

      old_window = window
      window.move(ypos, xpos)
      begin
        #window = Curses::Window.new(old_window.begy, old_window.begx, ypos, xpos)
        old_window.erase
        #window
      rescue
        self.Beep
      end
    end

    def self.digit?(character)
      !(character.match(/^[[:digit:]]$/).nil?)
    end

    def self.alpha?(character)
      !(character.match(/^[[:alpha:]]$/).nil?)
    end

    def self.isChar(c)
      c.ord >= 0 && c.ord < Curses::KEY_MIN
    end

    def self.KEY_F(n)
      264 + n
    end

    def self.Version
      return "%d.%d - %d" % [
        Slithernix::Cdk::VERSION_MAJOR,
        Slithernix::Cdk::VERSION_MINOR,
        Slithernix::Cdk::VERSION_PATCH,
      ]
    end

    def self.getString(screen, title, label, init_value)
      # Create the widget.
      widget = Slithernix::Cdk::Entry.new(screen, Slithernix::Cdk::CENTER, Slithernix::Cdk::CENTER, title, label,
                              Curses::A_NORMAL, '.', :MIXED, 40, 0, 5000, true, false)

      # Set the default value.
      widget.setValue(init_value)

      # Get the string.
      value = widget.activate([])

      # Make sure they exited normally.
      if widget.exit_type != :NORMAL
        widget.destroy
        return nil
      end

      # Return a copy of the string typed in.
      value = entry.getValue.clone
      widget.destroy
      return value
    end

    # This allows a person to select a file.
    def self.selectFile(screen, title)
      # Create the file selector.
      fselect = Slithernix::Cdk::FSelect.new(screen, Slithernix::Cdk::CENTER, Slithernix::Cdk::CENTER, -4, -20,
                                 title, 'File: ', Curses::A_NORMAL, '_', Curses::A_REVERSE,
                                 '</5>', '</48>', '</N>', '</N>', true, false)

      # Let the user play.
      filename = fselect.activate([])

      # Check the way the user exited the selector.
      if fselect.exit_type != :NORMAL
        fselect.destroy
        screen.refresh
        return nil
      end

      # Otherwise...
      fselect.destroy
      screen.refresh
      return filename
    end

    # This returns a selected value in a list
    def self.getListindex(screen, title, list, list_size, numbers)
      selected = -1
      height = 10
      width = -1
      len = 0

      # Determine the height of the list.
      if list_size < 10
        height = list_size + if title.size == 0 then 2 else 3 end
      end

      # Determine the width of the list.
      list.each do |item|
        width = [width, item.size + 10].max
      end

      width = [width, title.size].max
      width += 5

      # Create the scrolling list.
      scrollp = Slithernix::Cdk::Scroll.new(screen, Slithernix::Cdk::CENTER, Slithernix::Cdk::CENTER, Slithernix::Cdk::RIGHT,
                                height, width, title, list, list_size, numbers, Curses::A_REVERSE,
                                true, false)

      # Check if we made the lsit.
      if scrollp.nil?
        screen.refresh
        return -1
      end

      # Let the user play.
      selected = scrollp.activate([])

      # Check how they exited.
      if scrollp.exit_type != :NORMAL
        selected = -1
      end

      # Clean up.
      scrollp.destroy
      screen.refresh
      return selected
    end

    # This allows the user to view information.
    def self.viewInfo(screen, title, info, count, buttons, button_count,
                     interpret)
      selected = -1

      # Create the file viewer to view the file selected.
      viewer = Slithernix::Cdk::Viewer.new(screen, Slithernix::Cdk::CENTER, Slithernix::Cdk::CENTER, -6, -16,
                               buttons, button_count, Curses::A_REVERSE, true, true)

      # Set up the viewer title, and the contents to the widget.
      viewer.set(title, info, count, Curses::A_REVERSE, interpret, true, true)

      # Activate the viewer widget.
      selected = viewer.activate([])

      # Make sure they exited normally.
      if viewer.exit_type != :NORMAL
        viewer.destroy
        return -1
      end

      # Clean up and return the button index selected
      viewer.destroy
      return selected
    end

    # This allows the user to view a file.
    def self.viewFile(screen, title, filename, buttons, button_count)
      info = []
      result = 0

      # Open the file and read the contents.
      lines = self.readFile(filename, info)

      # If we couldn't read the file, return an error.
      if lines == -1
        result = lines
      else
        result = self.viewInfo(screen, title, info, lines, buttons,
                              button_count, true)
      end
      return result
    end
  end
end
