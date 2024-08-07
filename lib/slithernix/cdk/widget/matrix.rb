# frozen_string_literal: true

require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class Matrix < Slithernix::Cdk::Widget
        attr_accessor :info
        attr_reader :colvalues, :row, :col, :colwidths, :filler, :crow, :ccol

        MAX_MATRIX_ROWS = 1000
        MAX_MATRIX_COLS = 1000

        @@g_paste_buffer = String.new

        def initialize(cdkscreen, xplace, yplace, rows, cols, vrows, vcols, title, rowtitles, coltitles, colwidths, colvalues, rspace, cspace, filler, dominant, box, box_cell, shadow)
          super()
          Curses.curs_set(1)
          parent_width = cdkscreen.window.maxx
          parent_height = cdkscreen.window.maxy
          box_width = 0
          max_row_title_width = 0
          row_space = [0, rspace].max
          col_space = [0, cspace].max
          begx = 0
          begy = 0
          cell_width = 0
          have_rowtitles = false
          have_coltitles = false
          bindings = {
            Slithernix::Cdk::FORCHAR => Curses::KEY_NPAGE,
            Slithernix::Cdk::BACKCHAR => Curses::KEY_PPAGE
          }

          set_box(box)
          borderw = @box ? 1 : 0

          # Make sure that the number of rows/cols/vrows/vcols is not zero.
          if rows <= 0 || cols <= 0 || vrows <= 0 || vcols <= 0
            destroy
            return nil
          end

          @cell = Array.new(rows + 1) { |_i| Array.new(cols + 1) }
          @info = Array.new(rows + 1) { |_i| Array.new(cols + 1) { |_i| '' } }

          # Make sure the number of virtual cells is not larger than the
          # physical size.
          vrows = [vrows, rows].min
          vcols = [vcols, cols].min

          @rows = rows
          @cols = cols
          @colwidths = [0] * (cols + 1)
          @colvalues = [0] * (cols + 1)
          @coltitle = Array.new(cols + 1) { |_i| [] }
          @coltitle_len = [0] * (cols + 1)
          @coltitle_pos = [0] * (cols + 1)
          @rowtitle = Array.new(rows + 1) { |_i| [] }
          @rowtitle_len = [0] * (rows + 1)
          @rowtitle_pos = [0] * (rows + 1)

          # Count the number of lines in the title
          temp = title.split("\n")
          @title_lines = temp.size

          # Determine the height of the box.
          box_height = if vrows == 1
                         6 + @title_lines
                       elsif row_space.zero?
                         6 + @title_lines + ((vrows - 1) * 2)
                       else
                         3 + @title_lines + (vrows * 3) +
                           ((vrows - 1) * (row_space - 1))
                       end

          # Determine the maximum row title width.
          (1..rows).each do |x|
            if rowtitles && x < rowtitles.size && rowtitles[x].size&.positive?
              have_rowtitles = true
            end
            rowtitle_len = []
            rowtitle_pos = []
            @rowtitle[x] = Slithernix::Cdk.char_to_chtype(
              (rowtitles[x] || ''),
              rowtitle_len,
              rowtitle_pos,
            )
            @rowtitle_len[x] = rowtitle_len[0]
            @rowtitle_pos[x] = rowtitle_pos[0]
            max_row_title_width = [max_row_title_width, @rowtitle_len[x]].max
          end

          if have_rowtitles
            @maxrt = max_row_title_width + 2

            # We need to rejustify the row title cell info.
            (1..rows).each do |x|
              @rowtitle_pos[x] = Slithernix::Cdk.justify_string(
                @maxrt,
                @rowtitle_len[x],
                @rowtitle_pos[x],
              )
            end
          else
            @maxrt = 0
          end

          # Determine the width of the matrix.
          max_width = 2 + @maxrt
          (1..vcols).each do |x|
            max_width += colwidths[x] + 2 + col_space
          end
          max_width -= (col_space - 1)
          box_width = [max_width, box_width].max
          box_width = set_title(title, box_width)

          # Make sure the dimensions of the window didn't extend
          # beyond the dimensions of the parent window
          box_width = [box_width, parent_width].min
          box_height = [box_height, parent_height].min

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

          # Make the pop-up window.
          @win = Curses::Window.new(box_height, box_width, ypos, xpos)

          if @win.nil?
            destroy
            raise StandardError, 'could not start curses window'
          end

          # Make the subwindows in the pop-up.
          begx = xpos
          begy = ypos + borderw + @title_lines

          # Make the 'empty' 0x0 cell.
          @cell[0][0] = @win.subwin(3, @maxrt, begy, begx)

          begx += @maxrt + 1

          # Copy the titles into the structrue.
          (1..cols).each do |x|
            if coltitles && x < coltitles.size && coltitles[x].size.positive?
              have_coltitles = true
            end
            coltitle_len = []
            coltitle_pos = []
            @coltitle[x] = Slithernix::Cdk.char_to_chtype(
              coltitles[x] || '',
              coltitle_len,
              coltitle_pos,
            )
            @coltitle_len[x] = coltitle_len[0]
            @coltitle_pos[x] = @border_size + Slithernix::Cdk.justify_string(
              colwidths[x],
              @coltitle_len[x],
              coltitle_pos[0],
            )
            @colwidths[x] = colwidths[x]
          end

          if have_coltitles
            # Make the column titles.
            (1..vcols).each do |x|
              cell_width = colwidths[x] + 3
              @cell[0][x] = @win.subwin(borderw, cell_width, begy, begx)
              if @cell[0][x].nil?
                destroy
                return nil
              end
              begx += cell_width + col_space - 1
            end
            begy += 1
          end

          # Make the main cell body
          (1..vrows).each do |x|
            if have_rowtitles
              # Make the row titles
              @cell[x][0] = @win.subwin(3, @maxrt, begy, xpos + borderw)

              if @cell[x][0].nil?
                destroy
                return nil
              end
            end

            # Set the start of the x position.
            begx = xpos + @maxrt + borderw

            # Make the cells
            (1..vcols).each do |y|
              cell_width = colwidths[y] + 3
              @cell[x][y] = @win.subwin(3, cell_width, begy, begx)

              if @cell[x][y].nil?
                destroy
                return nil
              end
              begx += cell_width + col_space - 1
              @cell[x][y].keypad(true)
            end
            begy += row_space + 2
          end
          @win.keypad(true)

          # Keep the rest of the info.
          @screen = cdkscreen
          @accepts_focus = true
          @input_window = @win
          @parent = cdkscreen.window
          @vrows = vrows
          @vcols = vcols
          @box_width = box_width
          @box_height = box_height
          @row_space = row_space
          @col_space = col_space
          @filler = filler.ord
          @dominant = dominant
          @row = 1
          @col = 1
          @crow = 1
          @ccol = 1
          @trow = 1
          @lcol = 1
          @oldcrow = 1
          @oldccol = 1
          @oldvrow = 1
          @oldvcol = 1
          @box_cell = box_cell
          @shadow = shadow
          @highlight = Curses::A_REVERSE
          @shadow_win = nil
          @callbackfn = lambda do |matrix, input|
            disptype = matrix.colvalues[matrix.col]
            plainchar = Slithernix::Cdk::Display.filter_by_display_type(
              disptype,
              input,
            )
            charcount = matrix.info[matrix.row][matrix.col].size

            if plainchar == Curses::Error
              Slithernix::Cdk.beep
            elsif charcount == matrix.colwidths[matrix.col]
              Slithernix::Cdk.beep
            else
              matrix.current_cell.setpos(
                1,
                matrix.info[matrix.row][matrix.col].size + 1,
              )
              matrix.current_cell.addch(
                if Slithernix::Cdk::Display.is_hidden_display_type?(disptype)
                then matrix.filler
                else
                  plainchar
                end
              )
              matrix.current_cell.refresh

              # Update the info string
              matrix.info[matrix.row][matrix.col] =
                matrix.info[matrix.row][matrix.col][0...charcount] +
                plainchar.chr
            end
          end

          # Make room for the cell information.
          (1..rows).each do |_x|
            (1..cols).each do |y|
              @colvalues[y] = colvalues[y]
              @colwidths[y] = colwidths[y]
            end
          end

          @colvalues = colvalues.clone
          @colwidths = colwidths.clone

          if shadow
            @shadow_win = Curses::Window.new(
              box_height,
              box_width,
              ypos + 1,
              xpos + 1,
            )
          end

          # Set up the key bindings.
          bindings.each do |from, to|
            bind(:Matrix, from, :getc, to)
          end

          # Register this baby.
          cdkscreen.register(:Matrix, self)
        end

        # This activates the matrix.
        def activate(actions)
          draw(@box)

          if actions.nil? || actions.empty?
            while true
              @input_window = self.current_cell
              @input_window.keypad(true)
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
          set_exit_type(0)
          -1
        end

        # This injects a single character into the matrix widget.
        def inject(input)
          refresh_cells = false
          moved_cell = false
          charcount = @info[@row][@col].size
          pp_return = 1
          ret = -1
          complete = false

          # Set the exit type.
          set_exit_type(0)

          # Move the cursor to the correct position within the cell.
          if @colwidths[@ccol] == 1
            self.current_cell.setpos(1, 1)
          else
            self.current_cell.setpos(1, @info[@row][@col].size + 1)
          end

          # Put the focus on the current cell.
          focus_current

          # Check if there is a pre-process function to be called.
          unless @pre_process_func.nil?
            # Call the pre-process function.
            pp_return = @pre_process_func.call(:Matrix, self,
                                               @pre_process_data, input)
          end

          # Should we continue?
          if pp_return != 0
            # Check the key bindings.
            if check_bind(:Matrix, input)
              complete = true
            else
              case input
              when Slithernix::Cdk::TRANSPOSE
              when Curses::KEY_HOME
              when Curses::KEY_END
              when Curses::KEY_BACKSPACE, Curses::KEY_DC
                if @colvalues[@col] == :VIEWONLY || charcount <= 0
                  Slithernix::Cdk.beep
                else
                  charcount -= 1
                  self.current_cell.mvwdelch(1, charcount + 1)
                  self.current_cell.mvwinsch(1, charcount + 1, @filler)

                  self.current_cell.refresh
                  @info[@row][@col] = @info[@row][@col][0...charcount]
                end
              when Curses::KEY_RIGHT, Slithernix::Cdk::KEY_TAB
                if @ccol == @vcols
                  # We have to shift the columns to the right.
                  if @col != @cols
                    @lcol += 1
                    @col += 1

                    # Redraw the column titles.
                    redraw_titles(false, true) if @rows > @vrows
                    refresh_cells = true
                    moved_cell = true
                  elsif @row == @rows
                    # We are at the far right column, we need to shift
                    # down one row, if we can.
                    Slithernix::Cdk.beep
                  else
                    # Set up the columns info.
                    @col = 1
                    @lcol = 1
                    @ccol = 1

                    # Shift the rows...
                    @row += 1
                    if @crow == @vrows
                      @trow += 1
                    else
                      @crow += 1
                    end
                    redraw_titles(true, true)
                    refresh_cells = true
                    moved_cell = true
                  end
                else
                  # We are moving to the right...
                  @col += 1
                  @ccol += 1
                  moved_cell = true
                end
              when Curses::KEY_LEFT, Curses::KEY_BTAB
                if @ccol == 1
                  # Are we at the far left?
                  if @lcol != 1
                    @lcol -= 1
                    @col -= 1

                    # Redraw the column titles.
                    redraw_titles(false, true) if @cols > @vcols
                    refresh_cells = true
                    moved_cell = true
                  elsif @row == 1
                    # Shift up one line if we can...
                    Slithernix::Cdk.beep
                  else
                    # Set up the columns info.
                    @col = @cols
                    @lcol = @cols - @vcols + 1
                    @ccol = @vcols

                    # Shift the rows...
                    @row -= 1
                    if @crow == 1
                      @trow -= 1
                    else
                      @crow -= 1
                    end
                    redraw_titles(true, true)
                    refresh_cells = true
                    moved_cell = true
                  end
                else
                  # We are moving to the left...
                  @col -= 1
                  @ccol -= 1
                  moved_cell = true
                end
              when Curses::KEY_UP
                if @crow == 1
                  if @trow == 1
                    Slithernix::Cdk.beep
                  else
                    @trow -= 1
                    @row -= 1

                    # Redraw the row titles.
                    redraw_titles(true, false) if @rows > @vrows
                    refresh_cells = true
                    moved_cell = true
                  end
                else
                  @row -= 1
                  @crow -= 1
                  moved_cell = true
                end
              when Curses::KEY_DOWN
                if @crow == @vrows
                  if @trow + @vrows - 1 == @rows
                    Slithernix::Cdk.beep
                  else
                    @trow += 1
                    @row += 1

                    # Redraw the titles.
                    redraw_titles(true, false) if @rows > @vrows
                    refresh_cells = true
                    moved_cell = true
                  end
                else
                  @row += 1
                  @crow += 1
                  moved_cell = true
                end
              when Curses::KEY_NPAGE
                if @rows > @vrows
                  if @trow + ((@vrows - 1) * 2) <= @rows
                    @trow += @vrows - 1
                    @row += @vrows - 1
                    redraw_titles(true, false)
                    refresh_cells = true
                    moved_cell = true
                  else
                    Slithernix::Cdk.beep
                  end
                else
                  Slithernix::Cdk.beep
                end
              when Curses::KEY_PPAGE
                if @rows > @vrows
                  if @trow - ((@vrows - 1) * 2) >= 1
                    @trow -= @vrows - 1
                    @row -= @vrows - 1
                    redraw_titles(true, false)
                    refresh_cells = true
                    moved_cell = true
                  else
                    Slithernix::Cdk.beep
                  end
                else
                  Slithernix::Cdk.beep
                end
              when Slithernix::Cdk.ctrl('G')
                jump_to_cell(-1, -1)
                draw(@box)
              when Slithernix::Cdk::PASTE
                if @@g_paste_buffer.empty? ||
                   @@g_paste_buffer.size > @colwidths[@ccol]
                  Slithernix::Cdk.beep
                else
                  self.current_info = @@g_paste_buffer.clone
                  draw_cur_cell
                end
              when Slithernix::Cdk::COPY
                @@g_paste_buffer = self.current_info.clone
              when Slithernix::Cdk::CUT
                @@g_paste_buffer = self.current_info.clone
                clean_cell(@trow + @crow - 1, @lcol + @ccol - 1)
                draw_cur_cell
              when Slithernix::Cdk::ERASE
                clean_cell(@trow + @crow - 1, @lcol + @ccol - 1)
                draw_cur_cell
              when Curses::KEY_ENTER, Slithernix::Cdk::KEY_RETURN
                if @box_cell
                  draw_old_cell
                else
                  Slithernix::Cdk::Draw.attrbox(@cell[@oldcrow][@oldccol], ' '.ord, ' '.ord,
                                                ' '.ord, ' '.ord, ' '.ord, ' '.ord, Curses::A_NORMAL)
                end
                self.current_cell.refresh
                set_exit_type(input)
                ret = 1
                complete = true
              when Curses::Error
                set_exit_type(input)
                complete = true
              when Slithernix::Cdk::KEY_ESC
                if @box_cell
                  draw_old_cell
                else
                  Slithernix::Cdk::Draw.attrbox(@cell[@oldcrow][@oldccol], ' '.ord, ' '.ord,
                                                ' '.ord, ' '.ord, ' '.ord, ' '.ord, Curses::A_NORMAL)
                end
                self.current_cell.refresh
                set_exit_type(input)
                complete = true
              when Slithernix::Cdk::REFRESH
                @screen.erase
                @screen.refresh
              else
                @callbackfn.call(self, input)
              end
            end

            unless complete
              # Did we change cells?
              if moved_cell
                # un-highlight the old box
                if @box_cell
                  draw_old_cell
                else
                  Slithernix::Cdk::Draw.attrbox(@cell[@oldcrow][@oldccol], ' '.ord, ' '.ord,
                                                ' '.ord, ' '.ord, ' '.ord, ' '.ord, Curses::A_NORMAL)
                end
                @cell[@oldcrow][@oldccol].refresh

                focus_current
              end

              # Redraw each cell
              if refresh_cells
                draw_each_cell
                focus_current
              end

              # Move to the correct position in the cell.
              if refresh_cells || moved_cell
                if @colwidths[@ccol] == 1
                  self.current_cell.setpos(1, 1)
                else
                  self.current_cell.setpos(1, self.current_info.size + 1)
                end
                self.current_cell.refresh
              end

              # Should we call a post-process?
              @post_process_func&.call(:Matrix, self, @post_process_data,
                                       input)
            end
          end

          unless complete
            # Set the variables we need.
            @oldcrow = @crow
            @oldccol = @ccol
            @oldvrow = @row
            @oldvcol = @col

            # Set the exit type and exit.
            set_exit_type(0)
          end

          @result_data = ret
          ret
        end

        # Highlight the new field.
        def highlight_cell
          disptype = @colvalues[@col]
          highlight = @highlight
          infolen = @info[@row][@col].size

          # Given the dominance of the color/attributes, we need to set the
          # current cell attribute.
          if @dominant == Slithernix::Cdk::ROW
            highlight = (@rowtitle[@crow][0] || 0) & Curses::A_ATTRIBUTES
          elsif @dominant == Slithernix::Cdk::COL
            highlight = (@coltitle[@ccol][0] || 0) & Curses::A_ATTRIBUTES
          end

          # If the column is only one char.
          (1..@colwidths[@ccol]).each do |x|
            ch = if x <= infolen && !Slithernix::Cdk::Display.is_hidden_display_type?(disptype)
                 then Slithernix::Cdk.chtype_to_char(@info[@row][@col][x - 1])
                 else
                   @filler
                 end
            self.current_cell.mvwaddch(1, x, ch.ord | highlight)
          end
          self.current_cell.setpos(1, infolen + 1)
          self.current_cell.refresh
        end

        # This moves the matrix field to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@win]

          (0..@vrows).each do |x|
            (0..@vcols).each do |y|
              windows << @cell[x][y]
            end
          end

          windows << @shadow_win
          move_specific(
            xplace,
            yplace,
            relative,
            refresh_flag,
            windows,
            []
          )
        end

        # This draws a cell within a matrix.
        def draw_cell(row, col, vrow, vcol, attr, box)
          disptype = @colvalues[@col]
          highlight = @filler & Curses::A_ATTRIBUTES
          rows = @vrows
          cols = @vcols
          infolen = @info[vrow][vcol].size

          # Given the dominance of the colors/attributes, we need to set the
          # current cell attribute.
          if @dominant == Slithernix::Cdk::ROW
            highlight = (@rowtitle[row][0] || 0) & Curses::A_ATTRIBUTES
          elsif @dominant == Slithernix::Cdk::COL
            highlight = (@coltitle[col][0] || 0) & Curses::A_ATTRIBUTES
          end

          # Draw in the cell info.
          (1..@colwidths[col]).each do |x|
            ch = if x <= infolen && !Slithernix::Cdk::Display.is_hidden_display_type?(disptype)
                 then Slithernix::Cdk.chtype_to_char(@info[vrow][vcol][x - 1]).ord | highlight
                 else
                   @filler
                 end
            @cell[row][col].mvwaddch(1, x, ch.ord | highlight)
          end

          @cell[row][col].setpos(1, infolen + 1)
          @cell[row][col].refresh

          # Only draw the box iff the user asked for a box.
          return unless box

          # If the value of the column spacing is greater than 0 then these
          # are independent boxes
          if @col_space != 0 && @row_space != 0
            Slithernix::Cdk::Draw.attrbox(
              @cell[row][col],
              Slithernix::Cdk::ACS_ULCORNER,
              Slithernix::Cdk::ACS_URCORNER,
              Slithernix::Cdk::ACS_LLCORNER,
              Slithernix::Cdk::ACS_LRCORNER,
              Slithernix::Cdk::ACS_HLINE,
              Slithernix::Cdk::ACS_VLINE,
              attr
            )
            return
          end
          if @col_space != 0 && @row_space.zero?
            if row == 1
              Slithernix::Cdk::Draw.attrbox(
                @cell[row][col],
                Slithernix::Cdk::ACS_ULCORNER,
                Slithernix::Cdk::ACS_URCORNER,
                Slithernix::Cdk::ACS_LTEE,
                Slithernix::Cdk::ACS_RTEE,
                Slithernix::Cdk::ACS_HLINE,
                Slithernix::Cdk::ACS_VLINE,
                attr
              )
              return
            elsif row > 1 && row < rows
              Slithernix::Cdk::Draw.attrbox(
                @cell[row][col],
                Slithernix::Cdk::ACS_LTEE,
                Slithernix::Cdk::ACS_RTEE,
                Slithernix::Cdk::ACS_LTEE,
                Slithernix::Cdk::ACS_RTEE,
                Slithernix::Cdk::ACS_HLINE,
                Slithernix::Cdk::ACS_VLINE,
                attr
              )
              return
            elsif row == rows
              Slithernix::Cdk::Draw.attrbox(
                @cell[row][col],
                Slithernix::Cdk::ACS_LTEE,
                Slithernix::Cdk::ACS_RTEE,
                Slithernix::Cdk::ACS_LLCORNER,
                Slithernix::Cdk::ACS_LRCORNER,
                Slithernix::Cdk::ACS_HLINE,
                Slithernix::Cdk::ACS_VLINE,
                attr
              )
              return
            end
          end
          if @col_space.zero? && @row_space != 0
            if col == 1
              Slithernix::Cdk::Draw.attrbox(
                @cell[row][col],
                Slithernix::Cdk::ACS_ULCORNER,
                Slithernix::Cdk::ACS_TTEE,
                Slithernix::Cdk::ACS_LLCORNER,
                Slithernix::Cdk::ACS_BTEE,
                Slithernix::Cdk::ACS_HLINE,
                Slithernix::Cdk::ACS_VLINE,
                attr,
              )
              return
            elsif col > 1 && col < cols
              Slithernix::Cdk::Draw.attrbox(
                @cell[row][col],
                Slithernix::Cdk::ACS_TTEE,
                Slithernix::Cdk::ACS_TTEE,
                Slithernix::Cdk::ACS_BTEE,
                Slithernix::Cdk::ACS_BTEE,
                Slithernix::Cdk::ACS_HLINE,
                Slithernix::Cdk::ACS_VLINE,
                attr,
              )
              return
            elsif col == cols
              Slithernix::Cdk::Draw.attrbox(
                @cell[row][col],
                Slithernix::Cdk::ACS_TTEE,
                Slithernix::Cdk::ACS_URCORNER,
                Slithernix::Cdk::ACS_BTEE,
                Slithernix::Cdk::ACS_LRCORNER,
                Slithernix::Cdk::ACS_HLINE,
                Slithernix::Cdk::ACS_VLINE,
                attr
              )
              return
            end
          end

          # Start drawing the matrix.
          if row == 1
            if col == 1
              # Draw the top left corner
              Slithernix::Cdk::Draw.attrbox(
                @cell[row][col],
                Slithernix::Cdk::ACS_ULCORNER,
                Slithernix::Cdk::ACS_TTEE,
                Slithernix::Cdk::ACS_LTEE,
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_HLINE,
                Slithernix::Cdk::ACS_VLINE,
                attr,
              )
            elsif col > 1 && col < cols
              # Draw the top middle box
              Slithernix::Cdk::Draw.attrbox(
                @cell[row][col],
                Slithernix::Cdk::ACS_TTEE,
                Slithernix::Cdk::ACS_TTEE,
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_HLINE,
                Slithernix::Cdk::ACS_VLINE,
                attr,
              )
            elsif col == cols
              # Draw the top right corner
              Slithernix::Cdk::Draw.attrbox(
                @cell[row][col],
                Slithernix::Cdk::ACS_TTEE,
                Slithernix::Cdk::ACS_URCORNER,
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_RTEE,
                Slithernix::Cdk::ACS_HLINE,
                Slithernix::Cdk::ACS_VLINE,
                attr,
              )
            end
          elsif row > 1 && row < rows
            if col == 1
              # Draw the middle left box
              Slithernix::Cdk::Draw.attrbox(
                @cell[row][col],
                Slithernix::Cdk::ACS_LTEE,
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_LTEE,
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_HLINE,
                Slithernix::Cdk::ACS_VLINE,
                attr,
              )
            elsif col > 1 && col < cols
              # Draw the middle box
              Slithernix::Cdk::Draw.attrbox(
                @cell[row][col],
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_HLINE,
                Slithernix::Cdk::ACS_VLINE,
                attr,
              )
            elsif col == cols
              # Draw the middle right box
              Slithernix::Cdk::Draw.attrbox(
                @cell[row][col],
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_RTEE,
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_RTEE,
                Slithernix::Cdk::ACS_HLINE,
                Slithernix::Cdk::ACS_VLINE,
                attr,
              )
            end
          elsif row == rows
            if col == 1
              # Draw the bottom left corner
              Slithernix::Cdk::Draw.attrbox(
                @cell[row][col],
                Slithernix::Cdk::ACS_LTEE,
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_LLCORNER,
                Slithernix::Cdk::ACS_BTEE,
                Slithernix::Cdk::ACS_HLINE,
                Slithernix::Cdk::ACS_VLINE,
                attr,
              )
            elsif col > 1 && col < cols
              # Draw the bottom middle box
              Slithernix::Cdk::Draw.attrbox(
                @cell[row][col],
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_BTEE,
                Slithernix::Cdk::ACS_BTEE,
                Slithernix::Cdk::ACS_HLINE,
                Slithernix::Cdk::ACS_VLINE,
                attr,
              )
            elsif col == cols
              # Draw the bottom right corner
              Slithernix::Cdk::Draw.attrbox(
                @cell[row][col],
                Slithernix::Cdk::ACS_PLUS,
                Slithernix::Cdk::ACS_RTEE,
                Slithernix::Cdk::ACS_BTEE,
                Slithernix::Cdk::ACS_LRCORNER,
                Slithernix::Cdk::ACS_HLINE,
                Slithernix::Cdk::ACS_VLINE,
                attr,
              )
            end
          end

          focus_current
        end

        def draw_each_col_title
          (1..@vcols).each do |x|
            next if @cell[0][x].nil?

            @cell[0][x].erase
            Slithernix::Cdk::Draw.write_chtype(@cell[0][x],
                                               @coltitle_pos[@lcol + x - 1], 0,
                                               @coltitle[@lcol + x - 1], Slithernix::Cdk::HORIZONTAL, 0,
                                               @coltitle_len[@lcol + x - 1])
            @cell[0][x].refresh
          end
        end

        def draw_each_row_title
          (1..@vrows).each do |x|
            next if @cell[x][0].nil?

            @cell[x][0].erase
            Slithernix::Cdk::Draw.write_chtype(
              @cell[x][0],
              @rowtitle_pos[@trow + x - 1],
              1,
              @rowtitle[@trow + x - 1],
              Slithernix::Cdk::HORIZONTAL,
              0,
              @rowtitle_len[@trow + x - 1],
            )
            @cell[x][0].refresh
          end
        end

        def draw_each_cell
          # Fill in the cells.
          (1..@vrows).each do |x|
            (1..@vcols).each do |y|
              draw_cell(
                x,
                y,
                @trow + x - 1,
                @lcol + y - 1,
                Curses::A_NORMAL,
                @box_cell,
              )
            end
          end
        end

        def draw_cur_cell
          draw_cell(@crow, @ccol, @row, @col, Curses::A_NORMAL, @box_cell)
        end

        def draw_old_cell
          draw_cell(
            @oldcrow,
            @oldccol,
            @oldvrow,
            @oldvcol,
            Curses::A_NORMAL,
            @box_cell,
          )
        end

        # This function draws the matrix widget.
        def draw(box)
          # Did we ask for a shadow?
          unless @shadow_win.nil?
            Slithernix::Cdk::Draw.draw_shadow(@shadow_win)
          end

          # Should we box the matrix?
          Slithernix::Cdk::Draw.draw_obj_box(@win, self) if box

          draw_title(@win)

          @win.refresh

          draw_each_col_title
          draw_each_row_title
          draw_each_cell
          focus_current
        end

        # This function destroys the matrix widget.
        def destroy
          clean_title

          # Clear the matrix windows.
          Slithernix::Cdk.delete_curses_window(@cell[0][0])
          (1..@vrows).each do |x|
            Slithernix::Cdk.delete_curses_window(@cell[x][0])
          end
          (1..@vcols).each do |x|
            Slithernix::Cdk.delete_curses_window(@cell[0][x])
          end
          (1..@vrows).each do |x|
            (1..@vcols).each do |y|
              Slithernix::Cdk.delete_curses_window(@cell[x][y])
            end
          end

          Slithernix::Cdk.delete_curses_window(@shadow_win)
          Slithernix::Cdk.delete_curses_window(@win)

          # Clean the key bindings.
          clean_bindings(:Matrix)

          # Unregister this widget.
          Slithernix::Cdk::Screen.unregister(:Matrix, self)
        end

        # This function erases the matrix widget from the screen.
        def erase
          return unless is_valid_widget?

          # Clear the matrix cells.
          Slithernix::Cdk.erase_curses_window(@cell[0][0])
          (1..@vrows).each do |x|
            Slithernix::Cdk.erase_curses_window(@cell[x][0])
          end
          (1..@vcols).each do |x|
            Slithernix::Cdk.erase_curses_window(@cell[0][x])
          end
          (1..@vrows).each do |x|
            (1..@vcols).each do |y|
              Slithernix::Cdk.erase_curses_window(@cell[x][y])
            end
          end
          Slithernix::Cdk.erase_curses_window(@shadow_win)
          Slithernix::Cdk.erase_curses_window(@win)
        end

        # Set the callback function
        def set_callback(callback)
          @callbackfn = callback
        end

        # This function sets the values of the matrix widget.
        def set_cells(_info, rows, _maxcols, sub_size)
          rows = @rows if rows > @rows

          # Copy in the new info.
          (1..rows).each do |x|
            (1..@cols).each do |y|
              if x <= rows && y <= sub_size[x]
                @info[x][y] =
                  @info[x][y][0..[@colwidths[y], @info[x][y].size].min]
              else
                clean_cell(x, y)
              end
            end
          end
        end

        # This cleans out the information cells in the matrix widget.
        def clean
          (1..@rows).each do |x|
            (1..@cols).each do |y|
              clean_cell(x, y)
            end
          end
        end

        # This cleans one cell in the matrix widget.
        def clean_cell(row, col)
          unless row.positive? && row <= @rows && col > col && col <= @cols
            return
          end

          @info[row][col] =
            ''
        end

        # This allows us to hyper-warp to a cell
        def jump_to_cell(row, col)
          new_row = row
          new_col = col

          # Only create the row scale if needed.
          if (row == -1) || (row > @rows)
            # Create the row scale widget.
            scale = Slithernix::Cdk::Scale.new(
              @screen,
              Slithernix::Cdk::CENTER,
              Slithernix::Cdk::CENTER,
              '<C>Jump to which row.',
              '</5/B>Row: ',
              Curses::A_NORMAL,
              5,
              1,
              1,
              @rows,
              1,
              1,
              true,
              false,
            )

            # Activate the scale and get the row.
            new_row = scale.activate([])
            scale.destroy
          end

          # Only create the column scale if needed.
          if (col == -1) || (col > @cols)
            # Create the column scale widget.
            scale = Slithernix::Cdk::Scale.new(
              @screen,Slithernix::Cdk::CENTER,
              Slithernix::Cdk::CENTER,
              '<C>Jump to which column','</5/B>Col: ',
              Curses::A_NORMAL,
              5,
              1,
              1,
              @cols,
              1,
              1,
              true,
              false
            )

            # Activate the scale and get the column.
            new_col = scale.activate([])
            scale.destroy
          end

          # Hyper-warp....
          if new_row != @row || @new_col != @col
            move_to_cell(new_row, new_col)
          else
            1
          end
        end

        # This allows us to move to a given cell.
        def move_to_cell(newrow, newcol)
          row_shift = newrow - @row
          col_shift = newcol - @col

          # Make sure we aren't asking to move out of the matrix.
          if newrow > @rows || newcol > @cols || newrow <= 0 || newcol <= 0
            return 0
          end

          # Did we move up/down?
          if row_shift.positive?
            # We are moving down
            if @vrows == @cols
              @trow = 1
              @crow = newrow
              @row = newrow
            elsif row_shift + @vrows < @rows
              @trow += row_shift
              @crow = 1
              @row += row_shift
            # Just shift down by row_shift
            else
              # We need to munge the values
              @trow = @rows - @vrows + 1
              @crow = row_shift + @vrows - @rows + 1
              @row = newrow
            end
          elsif row_shift.negative?
            # We are moving up.
            if @vrows == @rows
              @trow = 1
              @row = newrow
              @crow = newrow
            elsif row_shift + @vrows > 1
              @trow += row_shift
              @row += row_shift
              @crow = 1
            # Just shift up by row_shift...
            else
              # We need to munge the values
              @trow = 1
              @crow = 1
              @row = 1
            end
          end

          # Did we move left/right?
          if col_shift.positive?
            # We are moving right.
            if @vcols == @cols
              @lcol = 1
              @ccol = newcol
              @col = newcol
            elsif col_shift + @vcols < @cols
              @lcol += col_shift
              @ccol = 1
              @col += col_shift
            else
              # We need to munge with the values
              @lcol = @cols - @vcols + 1
              @ccol = col_shift + @vcols - @cols + 1
              @col = newcol
            end
          elsif col_shift.negative?
            # We are moving left.
            if @vcols == @cols
              @lcol = 1
              @col = newcol
              @ccol = newcol
            elsif col_shift + @vcols > 1
              @lcol += col_shift
              @col += col_shift
              @ccol = 1
            # Just shift left by col_shift
            else
              @lcol = 1
              @col = 1
              @ccol = 1
            end
          end

          # Keep the 'old' values around for redrawing sake.
          @oldcrow = @crow
          @oldccol = @ccol
          @oldvrow = @row
          @oldvcol = @col

          1
        end

        # This redraws the titles indicated...
        def redraw_titles(row_titles, col_titles)
          # Redraw the row titles.
          draw_each_row_title if row_titles

          # Redraw the column titles.
          draw_each_col_title if col_titles
        end

        # This sets the value of a matrix cell.
        def set_cell(row, col, value)
          # Make sure the row/col combination is within the matrix.
          return -1 if row > @rows || cols > @cols || row <= 0 || col <= 0

          clean_cell(row, col)
          @info[row][col] = value[0...[@colwidths[col], value.size].min]
          1
        end

        # This gets the value of a matrix cell.
        def get_cell(row, col)
          # Make sure the row/col combination is within the matrix.
          return 0 if row > @rows || col > @cols || row <= 0 || col <= 0

          @info[row][col]
        end

        def current_cell
          @cell[@crow][@ccol]
        end

        def current_info
          @info[@trow + @crow - 1][@lcol + @ccol - 1]
        end

        def focus_current
          Slithernix::Cdk::Draw.attrbox(
            self.current_cell,
            Slithernix::Cdk::ACS_ULCORNER,
            Slithernix::Cdk::ACS_URCORNER,
            Slithernix::Cdk::ACS_LLCORNER,
            Slithernix::Cdk::ACS_LRCORNER,
            Slithernix::Cdk::ACS_HLINE,
            Slithernix::Cdk::ACS_VLINE,
            Curses::A_BOLD
          )
          self.current_cell.refresh
          highlight_cell
        end

        # This returns the current row/col cell
        def get_col
          @col
        end

        def get_row
          @row
        end

        # This sets the background attribute of the widget.
        def set_background_attr(attrib)
          @win.wbkgd(attrib)
          (0..@vrows).each do |_x|
            (0..@vcols).each do |y|
              # wbkgd (MATRIX_CELL (widget, x, y), attrib);
            end
          end
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
