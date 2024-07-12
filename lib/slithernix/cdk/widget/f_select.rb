# frozen_string_literal: true

require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class FSelect < Slithernix::Cdk::Widget
        attr_reader :scroll_field,
                    :entry_field,
                    :dir_attribute,
                    :file_attribute,
                    :link_attribute,
                    :highlight,
                    :sock_attribute,
                    :field_attribute,
                    :filler_character,
                    :dir_contents,
                    :file_counter,
                    :pwd,
                    :pathname

        def initialize(cdkscreen, xplace, yplace, height, width, title, label, field_attribute, filler_char, highlight, d_attribute, f_attribute, l_attribute, s_attribute, box, shadow)
          super()
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          bindings = {
            Slithernix::Cdk::BACKCHAR => Curses::KEY_PPAGE,
            Slithernix::Cdk::FORCHAR => Curses::KEY_NPAGE
          }

          set_box(box)

          # If the height is a negative value the height will be ROWS-height,
          # otherwise the height will be the given height
          box_height = Slithernix::Cdk.set_widget_dimension(
            parent_height,
            height,
            0,
          )

          # If the width is a negative value, the width will be COLS-width,
          # otherwise the width will be the given width.
          box_width = Slithernix::Cdk.set_widget_dimension(
            parent_width,
            width,
            0,
          )

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

          # Make sure the box isn't too small.
          box_width = [box_width, 15].max
          box_height = [box_height, 6].max

          # Make the file selector window.
          @win = Curses::Window.new(box_height, box_width, ypos, xpos)

          # is the window nil?
          if @win.nil?
            fselect.destroy
            return nil
          end
          @win.keypad(true)

          # Set some variables.
          @screen = cdkscreen
          @parent = cdkscreen.window
          @dir_attribute = d_attribute.clone
          @file_attribute = f_attribute.clone
          @link_attribute = l_attribute.clone
          @sock_attribute = s_attribute.clone
          @highlight = highlight
          @filler_character = filler_char
          @field_attribute = field_attribute
          @box_height = box_height
          @box_width = box_width
          @file_counter = 0
          @pwd = String.new
          @input_window = @win
          @shadow = shadow
          @shadow_win = nil

          # Get the present working directory.
          # XXX need error handling (set to '.' on error)
          @pwd = Dir.getwd

          # Get the contents of the current directory
          set_dir_contents

          # Create the entry field in the selector
          label_len = []
          Slithernix::Cdk.char_to_chtype(label, label_len, [])
          label_len = label_len[0]

          temp_width = if Slithernix::Cdk::Widget::FSelect.is_full_width?(width)
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
            field_attribute,
            filler_char,
            :MIXED,
            temp_width,
            0,
            512,
            box,
            false,
          )

          # Make sure the widget was created.
          if @entry_field.nil?
            destroy
            return nil
          end

          # Set the lower left/right characters of the entry field.
          @entry_field.set_lower_left_corner_char(Slithernix::Cdk::ACS_LTEE)
          @entry_field.set_lower_right_corner_char(Slithernix::Cdk::ACS_RTEE)

          # This is a callback to the scrolling list which displays information
          # about the current file.  (and the whole directory as well)
          display_file_info_cb = lambda do |_widget_type, entry, fselect, _key|
            # Get the file name.
            filename = fselect.entry_field.info

            # Get specific information about the files.
            # lstat (filename, &fileStat);
            file_stat = File.stat(filename)

            # Determine the file type
            filetype = if file_stat.symlink?
                         'Symbolic Link'
                       elsif file_stat.socket?
                         'Socket'
                       elsif file_stat.file?
                         'Regular File'
                       elsif file_stat.directory?
                         'Directory'
                       elsif file_stat.chardev?
                         'Character Device'
                       elsif file_stat.blockdev?
                         'Block Device'
                       elsif file_stat.ftype == 'fif'
                         'FIFO Device'
                       else
                         'Unknown'
                       end

            # Get the user name and group name.
            pw_ent = Etc.getpwuid(file_stat.uid)
            gr_ent = Etc.getgrgid(file_stat.gid)

            # Convert the mode to both string and int
            # intMode = mode2Char (stringMode, fileStat.st_mode);

            # Create the message.
            mesg = [
              format('Directory  : </U>%s', fselect.pwd),
              format('Filename   : </U>%s', filename),
              format('Owner      : </U>%s<!U> (%d)', pw_ent.name,
                     file_stat.uid),
              format('Group      : </U>%s<!U> (%d)', gr_ent.name,
                     file_stat.gid),
              format('Permissions: </U>%s<!U> (%o)', string_mode, int_mode),
              format('Size       : </U>%ld<!U> bytes', file_stat.size),
              format('Last Access: </U>%s', file_stat.atime),
              format('Last Change: </U>%s', file_stat.ctime),
              format('File Type  : </U>%s', filetype)
            ]

            # Create the pop up label.
            info_label = Slithernix::Cdk::Label.new(entry.screen, Slithernix::Cdk::CENTER, Slithernix::Cdk::CENTER,
                                                    mesg, 9, true, false)
            info_label.draw(true)
            info_label.getch([])

            info_label.destroy

            # Redraw the file selector.
            fselect.draw(fselect.box)
            true
          end

          # This tries to complete the filename
          complete_filename_cb = lambda do |_widget_type, _widget, fselect, _key|
            scrollp = fselect.scroll_field
            entry = fselect.entry_field
            filename = entry.info.clone
            mydirname = Slithernix::Cdk.dirname(filename)
            current_index = 0

            # Make sure the filename is not nil/empty.
            if filename.nil? || filename.empty?
              Slithernix::Cdk.beep
              return true
            end

            # Try to expand the filename if it starts with a ~
            unless (new_filename = Slithernix::Cdk::Widget::FSelect.expand_tilde(filename)).nil?
              filename = new_filename
              entry.set_value(filename)
              entry.draw(entry.box)
            end

            # Make sure we can change into the directory.
            is_directory = Dir.exist?(filename)
            # if (chdir (fselect->pwd) != 0)
            #    return FALSE;
            # Dir.chdir(fselect.pwd)

            # XXX original: isDirectory ? mydirname : filename
            fselect.set(
              is_directory ? filename : mydirname,
              fselect.field_attribute,
              fselect.filler_character,
              fselect.highlight,
              fselect.dir_attribute,
              fselect.file_attribute,
              fselect.link_attribute,
              fselect.sock_attribute,
              fselect.box
            )

            # If we can, change into the directory.
            # XXX original: if isDirectory (with 0 as success result)
            if is_directory
              entry.set_value(filename)
              entry.draw(entry.box)
            end

            # Create the file list.
            list = (0...fselect.file_counter).map do |x|
              fselect.content_to_path(fselect.dir_contents[x])
            end

            # Look for a unique filename match.
            index = Slithernix::Cdk.search_list(list, fselect.file_counter,
                                                filename)

            # If the index is less than zero, return we didn't find a match.
            if index.negative?
              Slithernix::Cdk.beep
            else
              # Move to the current item in the scrolling list.
              # difference = Index - scrollp->currentItem;
              # absoluteDifference = abs (difference);
              # if (difference < 0)
              # {
              #    for (x = 0; x < absoluteDifference; x++)
              #    {
              #       inject_scroller (fselect, KEY_UP);
              #    }
              # }
              # else if (difference > 0)
              # {
              #    for (x = 0; x < absoluteDifferene; x++)
              #    {
              #       inject_scroller (fselect, key_down);
              #    }
              # }
              scrollp.set_position(index)
              fselect.draw_scroller

              # Ok, we found a match, is the next item similar?
              if index + 1 < fselect.file_counter && index + 1 < list.size &&
                 list[index + 1][0..([filename.size,
                                      list[index + 1].size].min)] ==
                 filename
                current_index = index
                base_chars = filename.size
                matches = 0

                # Determine the number of files which match.
                while current_index < fselect.file_counter
                  if current_index + 1 < list.size && (list[current_index][0..(
                        [filename.size,
                         list[current_index].size].max)] == filename)
                    matches += 1
                  end
                  current_index += 1
                end

                # Start looking for the common base characters.
                loop do
                  secondary_matches = 0
                  (index...index + matches).each do |x|
                    if list[index][base_chars] == list[x][base_chars]
                      secondary_matches += 1
                    end
                  end

                  if secondary_matches != matches
                    Slithernix::Cdk.beep
                    break
                  end

                  # Inject the character into the entry field.
                  fselect.entry_field.inject(list[index][base_chars])
                  base_chars += 1
                end
              else
                # Set the entry field with the found item.
                entry.set_value(list[index])
                entry.draw(entry.box)
              end
            end

            true
          end

          # This allows the user to delete a file.

          # Start of callback functions.
          adjust_scroll_cb = lambda do |_widget_type, _widget, fselect, key|
            scrollp = fselect.scroll_field
            entry = fselect.entry_field

            if scrollp.list_size.positive?
              # Move the scrolling list.
              fselect.inject_scroller(key)

              # Get the currently highlighted filename.
              current = Slithernix::Cdk.chtype_string_to_unformatted_string(scrollp.item[scrollp.current_item])
              # current = CDK.chtype_string_to_formatted_string(scrollp.item[scrollp.current_item])
              current = current[0...-1]

              temp = Slithernix::Cdk::Widget::FSelect.make_pathname(
                fselect.pwd, current
              )

              # Set the value in the entry field.
              entry.set_value(temp)
              entry.draw(entry.box)

              return true
            end
            Slithernix::Cdk.beep
            false
          end

          # Define the callbacks for the entry field.
          @entry_field.bind(:Entry, Curses::KEY_UP, adjust_scroll_cb, self)
          @entry_field.bind(:Entry, Curses::KEY_PPAGE, adjust_scroll_cb, self)
          @entry_field.bind(:Entry, Curses::KEY_DOWN, adjust_scroll_cb, self)
          @entry_field.bind(:Entry, Curses::KEY_NPAGE, adjust_scroll_cb, self)
          @entry_field.bind(:Entry, Slithernix::Cdk::KEY_TAB,
                            complete_filename_cb, self)
          @entry_field.bind(:Entry, Slithernix::Cdk.ctrl('^'),
                            display_file_info_cb, self)

          # Put the current working directory in the entry field.
          @entry_field.set_value(@pwd)

          # Create the scrolling list in the selector.
          temp_height = @entry_field.win.maxy - @border_size
          temp_width = if Slithernix::Cdk::Widget::FSelect.is_full_width?(width)
                       then Slithernix::Cdk::FULL
                       else
                         box_width - 1
                       end
          @scroll_field = Slithernix::Cdk::Widget::Scroll.new(cdkscreen,
                                                              @win.begx, @win.begy + temp_height, Slithernix::Cdk::RIGHT,
                                                              box_height - temp_height, temp_width, '', @dir_contents,
                                                              @file_counter, false, @highlight, box, false)

          # Set the lower left/right characters of the entry field.
          @scroll_field.set_upper_left_corner_char(Slithernix::Cdk::ACS_LTEE)
          @scroll_field.set_upper_right_corner_char(Slithernix::Cdk::ACS_RTEE)

          # Do we want a shadow?
          if shadow
            @shadow_win = Curses::Window.new(
              box_height,
              box_width,
              ypos + 1,
              xpos + 1,
            )
          end

          # Setup the key bindings
          bindings.each do |from, to|
            bind(:FSelect, from, :getc, to)
          end

          cdkscreen.register(:FSelect, self)
        end

        # This erases the file selector from the screen.
        def erase
          return unless is_valid_widget?

          @scroll_field.erase
          @entry_field.erase
          Slithernix::Cdk.erase_curses_window(@win)
        end

        # This moves the fselect field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@win, @shadow_win]
          subwidgets = [@entry_field, @scroll_field]

          move_specific(
            xplace,
            yplace,
            relative,
            refresh_flag,
            windows,
            subwidgets
          )
        end

        # The fselect's focus resides in the entry widget. But the scroll widget
        # will not draw items highlighted unless it has focus.  Temporarily adjust
        # the focus of the scroll widget when drawing on it to get the right
        # highlighting.

        def save_focus
          @save = @scroll_field.has_focus
          @scroll_field.has_focus = @entry_field.has_focus
        end

        def restore_focus
          @scroll_field.has_focus = @save
        end

        def draw_scroller
          save_focus
          @scroll_field.draw(@scroll_field.box)
          restore_focus
        end

        def inject_scroller(key)
          save_focus
          @scroll_field.inject(key)
          restore_focus
        end

        # This draws the file selector.
        def draw(_box)
          # Draw in the shadow if we need to.
          unless @shadow_win.nil?
            Slithernix::Cdk::Draw.draw_shadow(@shadow_win)
          end

          # Draw in the entry field.
          @entry_field.draw(@entry_field.box)

          # Draw in the scroll field.
          draw_scroller
        end

        # This means you want to use the given file selector. It takes input
        # from the keyboard and when it's done it fills the entry info element
        # of the structure with what was typed.
        def activate(actions)
          input = 0
          ret = 0

          # Draw the widget.
          draw(@box)

          if actions.nil? || actions.empty?
            loop do
              input = @entry_field.getch([])

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
          set_exit_type(0)
          0
        end

        # This injects a single character into the file selector.
        def inject(input)
          ret = -1
          complete = false

          # Let the user play.
          filename = @entry_field.inject(input)

          # Copy the entry field exit_type to the file selector.
          @exit_type = @entry_field.exit_type

          # If we exited early, make sure we don't interpret it as a file.
          return 0 if @exit_type == :EARLY_EXIT

          # Can we change into the directory
          # file = Dir.chdir(filename)
          # if Dir.chdir(@pwd) != 0
          #  return 0
          # end

          # If it's not a directory, return the filename.
          if Dir.exist?(filename)
            # Set the file selector information.
            set(filename, @field_attribute, @filler_character, @highlight,
                @dir_attribute, @file_attribute, @link_attribute, @sock_attribute,
                @box)

            # Redraw the scrolling list.
            draw_scroller
          else
            # It's a regular file, create the full path
            @pathname = filename.clone

            # Return the complete pathname.
            ret = @pathname
            complete = true
          end

          set_exit_type(0) unless complete

          @result_data = ret
          ret
        end

        # This function sets the information inside the file selector.
        def set(directory, field_attrib, filler, highlight, dir_attribute, file_attribute, link_attribute, sock_attribute, _box)
          fscroll = @scroll_field
          fentry = @entry_field
          new_directory = String.new

          # keep the info sent to us.
          @field_attribute = field_attrib
          @filler_character = filler
          @highlight = highlight

          # Set the attributes of the entry field/scrolling list.
          set_filler_char(filler)
          set_highlight(highlight)

          # Only do the directory stuff if the directory is not nil.
          if directory&.size&.positive?
            # Try to expand the directory if it starts with a ~
            temp_dir = Slithernix::Cdk::Widget::FSelect.expand_tilde(directory)
            new_directory = if temp_dir&.size&.positive?
                              temp_dir
                            else
                              directory.clone
                            end

            # Change directories.
            if Dir.chdir(new_directory) != 0
              Slithernix::Cdk.beep

              # Could not get into the directory, pop up a little message.
              mesg = [
                format('<C>Could not change into %s', new_directory),
                format('<C></U>%s', 'Unknown reason.'),
                ' ',
                '<C>Press Any Key To Continue.'
              ]

              # Pop up a message.
              @screen.popup_label(mesg, 4)

              # Get out of here.
              erase
              draw(@box)
              return
            end
          end

          # if the information coming in is the same as the information
          # that is already there, there is no need to destroy it.
          @pwd = Dir.getwd if @pwd != directory

          @file_attribute = file_attribute.clone
          @dir_attribute = dir_attribute.clone
          @link_attribute = link_attribute.clone
          @sock_attribute = sock_attribute.clone

          # Set the contents of the entry field.
          fentry.set_value(@pwd)
          fentry.draw(fentry.box)

          # Get the directory contents.
          unless set_dir_contents
            Slithernix::Cdk.beep
            return
          end

          # Set the values in the scrolling list.
          fscroll.set_items(@dir_contents, @file_counter, false)
        end

        # This creates a list of the files in the current directory.
        def set_dir_contents
          dir_list = []

          # Get the directory contents
          file_count = Slithernix::Cdk.get_directory_contents(@pwd, dir_list)
          if file_count <= 0
            # We couldn't read the directory. Return.
            return false
          end

          @dir_contents = dir_list
          @file_counter = file_count

          # Set the properties of the files.
          (0...@file_counter).each do |x|
            attr = String.new

            # FIXME(original): access() would give a more correct answer
            # TODO: add error handling
            file_stat = File.stat(dir_list[x])
            mode = if file_stat.executable?
                     '*'
                   else
                     ' '
                   end

            if file_stat.symlink?
              attr = @link_attribute
              mode = '@'
            elsif file_stat.socket?
              attr = @sock_attribute
              mode = '&'
            elsif file_stat.file?
              attr = @file_attribute
            elsif file_stat.directory?
              attr = @dir_attribute
              mode = '/'
            end
            @dir_contents[x] = format('%s%s%s', attr, dir_list[x], mode)
          end
          true
        end

        def get_dir_contents(count)
          count << @file_counter
          @dir_contents
        end

        # This sets the current directory of the file selector.
        def set_directory(directory)
          fentry = @entry_field
          fscroll = @scroll_field
          result = 1

          # If the directory supplied is the same as what is already there, return.
          if @pwd != directory
            # Try to chdir into the given directory.
            if Dir.chdir(directory).zero?
              @pwd = Dir.getwd

              # Set the contents of the entry field.
              fentry.set_value(@pwd)
              fentry.draw(fentry.box)

              # Get the directory contents.
              if set_dir_contents
                # Set the values in the scrolling list.
                fscroll.set_items(@dir_contents, @file_counter, false)
              else
                result = 0
              end
            else
              result = 0
            end
          end
          result
        end

        def get_directory
          @pwd
        end

        # This sets the filler character of the entry field.
        def set_filler_char(filler)
          @filler_character = filler
          @entry_field.set_filler_char(filler)
        end

        def get_filler_char
          @filler_character
        end

        # This sets the highlight bar of the scrolling list.
        def set_highlight(highlight)
          @highlight = highlight
          @scroll_field.set_highlight(highlight)
        end

        def get_highlight
          @highlight
        end

        # This sets the attribute of the directory attribute in the
        # scrolling list.
        def set_dir_attribute(attribute)
          # Make sure they are not the same.
          return unless @dir_attribute != attribute

          @dir_attribute = attribute
          set_dir_contents
        end

        def get_dir_attribute
          @dir_attribute
        end

        # This sets the attribute of the link attribute in the scrolling list.
        def set_link_attribute(attribute)
          # Make sure they are not the same.
          return unless @link_attribute != attribute

          @link_attribute = attribute
          set_dir_contents
        end

        def get_link_attribute
          @link_attribute
        end

        # This sets the attribute of the socket attribute in the scrolling list.
        def set_socket_attribute(attribute)
          # Make sure they are not the same.
          return unless @sock_attribute != attribute

          @sock_attribute = attribute
          set_dir_contents
        end

        def get_socket_attribute
          @sock_attribute
        end

        # This sets the attribute of the file attribute in the scrolling list.
        def set_file_attribute(attribute)
          # Make sure they are not the same.
          return unless @file_attribute != attribute

          @file_attribute = attribute
          set_dir_contents
        end

        def get_file_attribute
          @file_attribute
        end

        # this sets the contents of the widget
        def set_contents(list, list_size)
          scrollp = @scroll_field
          entry = @entry_field

          return unless create_list(list, list_size)

          # Set the information in the scrolling list.
          scrollp.set(@dir_contents, @file_counter, false, scrollp.highlight,
                      scrollp.box)

          # Clean out the entry field.
          set_current_item(0)
          entry.clean

          # Redraw the widget.
          erase
          draw(@box)
        end

        def get_contents(size)
          size << @file_counter
          @dir_contents
        end

        # Get/set the current position in the scroll wiget.
        def get_current_item
          @scroll_field.get_current
        end

        def set_current_item(item)
          return unless @file_counter != 0

          @scroll_field.setCurrent(item)

          data = content_to_path(@dir_contents[@scroll_field.get_current_item])
          @entry_field.set_value(data)
        end

        # These functions set the draw characters of the widget.
        def set_upper_left_corner_char(character)
          @entry_field.set_upper_left_corner_char(character)
        end

        def set_upper_right_corner_char(character)
          @entry_field.set_upper_right_corner_char(character)
        end

        def set_lower_left_corner_char(character)
          @scroll_field.set_lower_left_corner_char(character)
        end

        def set_lower_right_corner_char(character)
          @scroll_field.set_lower_right_corner_char(character)
        end

        def set_vertical_line_char(character)
          @entry_field.set_vertical_line_char(character)
          @scroll_field.set_vertical_line_char(character)
        end

        def set_horizontal_line_char(character)
          @entry_field.set_horizontal_line_char(character)
          @scroll_field.set_horizontal_line_char(character)
        end

        def set_box_attr(character)
          @entry_field.set_box_attr(character)
          @scroll_field.set_box_attr(character)
        end

        # This sets the background attribute of the widget.
        def set_background_attr(attrib)
          @entry_field.set_background_attr(attrib)
          @scroll_field.set_background_attr(attrib)
        end

        # This destroys the file selector.
        def destroy
          clean_bindings(:FSelect)

          # Destroy the other CDK widgets
          @scroll_field.destroy
          @entry_field.destroy

          # Free up the windows
          Slithernix::Cdk.delete_curses_window(@shadow_win)
          Slithernix::Cdk.delete_curses_window(@win)

          # Clean the key bindings.
          # Unregister the widget.
          Slithernix::Cdk::Screen.unregister(:FSelect, self)
        end

        # Currently a wrapper for File.expand_path
        def self.make_pathname(directory, filename)
          if filename == '..'
            "#{File.expand_path(directory)}/.."
          else
            File.expand_path(filename, directory)
          end
        end

        # Return the plain string that corresponds to an item in dir_contents
        def content_to_path(content)
          # XXX direct translation of original but might be redundant
          temp_chtype = Slithernix::Cdk.char_to_chtype(content, [], [])
          temp_char = Slithernix::Cdk.chtype_string_to_unformatted_string(temp_chtype)
          temp_char = temp_char

          # Create the pathname.
          Slithernix::Cdk::Widget::FSelect.make_pathname(@pwd,
                                                         temp_char)
        end

        # Currently a wrapper for File.expand_path
        def self.expand_tilde(filename)
          File.expand_path(filename)
        end

        def destroy_info
          @dir_contents = []
          @file_counter = 0
        end

        def create_list(list, list_size)
          status = false

          if list_size >= 0
            newlist = []

            # Copy in the new information
            status = true
            (0...list_size).each do |x|
              newlist << list[x]
              if (newlist[x]).zero?
                status = false
                break
              end
            end

            if status
              destroy_info
              @file_counter = list_size
              @dir_contents = newlist
            end
          else
            destroy_info
            status = true
          end
          status
        end

        def focus
          @entry_field.focus
        end

        def unfocus
          @entry_field.unfocus
        end

        def self.is_full_width?(width)
          width == Slithernix::Cdk::FULL || (Curses.cols != 0 && width >= Curses.cols)
        end

        def position
          super(@win)
        end
      end
    end
  end
end
