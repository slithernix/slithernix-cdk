# frozen_string_literal: true

require_relative '../widget'

module Slithernix
  module Cdk
    class Widget
      class Menu < Slithernix::Cdk::Widget
        TITLELINES = 1
        MAX_MENU_ITEMS = 30
        MAX_SUB_ITEMS = 98

        attr_reader :current_title, :current_subtitle, :sublist

        def initialize(cdkscreen, menu_list, menu_items, subsize, menu_location, menu_pos, title_attr, subtitle_attr)
          super()
          rightloc = cdkscreen.window.maxx
          leftloc = 0
          xpos = cdkscreen.window.begx
          ypos = cdkscreen.window.begy
          ymax = cdkscreen.window.maxy

          # Start making a copy of the information.
          @screen = cdkscreen
          @box = false
          @accepts_focus = false
          rightcount = menu_items - 1
          @parent = cdkscreen.window
          @menu_items = menu_items
          @title_attr = title_attr
          @subtitle_attr = subtitle_attr
          @current_title = 0
          @current_subtitle = 0
          @last_selection = -1
          @menu_pos = menu_pos

          @pull_win = [nil] * menu_items
          @title_win = [nil] * menu_items
          @title = [''] * menu_items
          @title_len = [0] * menu_items
          @sublist = (1..menu_items).map { [nil] * subsize.max }.compact
          @sublist_len = (1..menu_items).map do
            [0] * subsize.max
          end.compact
          @subsize = [0] * menu_items

          # Create the pull down menus.
          (0...menu_items).each do |x|
            x1 = if menu_location[x] == Slithernix::Cdk::LEFT
                 then x
                 else
                   rightcount -= 1
                   rightcount + 1
                 end
            y1 = menu_pos == Slithernix::Cdk::BOTTOM ? ymax - 1 : 0
            y2 = if menu_pos == Slithernix::Cdk::BOTTOM
                 then ymax - subsize[x] - 2
                 else
                   Slithernix::Cdk::Widget::Menu::TITLELINES
                 end
            high = subsize[x] + Slithernix::Cdk::Widget::Menu::TITLELINES

            # Limit the menu height to fit on the screen.
            if high + y2 > ymax
              high = ymax - Slithernix::Cdk::Widget::Menu::TITLELINES
            end

            max = -1
            (Slithernix::Cdk::Widget::Menu::TITLELINES...subsize[x]).to_a.each do |y|
              y0 = y - Slithernix::Cdk::Widget::Menu::TITLELINES
              sublist_len = []
              @sublist[x1][y0] = Slithernix::Cdk.char_to_chtype(menu_list[x][y],
                                                                sublist_len, [])
              @sublist_len[x1][y0] = sublist_len[0]
              max = [max, sublist_len[0]].max
            end

            x2 = if menu_location[x] == Slithernix::Cdk::LEFT
                   leftloc
                 else
                   (rightloc -= max + 2)
                 end

            title_len = []
            @title[x1] =
              Slithernix::Cdk.char_to_chtype(menu_list[x][0], title_len, [])
            @title_len[x1] = title_len[0]
            @subsize[x1] =
              subsize[x] - Slithernix::Cdk::Widget::Menu::TITLELINES
            @title_win[x1] = cdkscreen.window.subwin(Slithernix::Cdk::Widget::Menu::TITLELINES,
                                                     @title_len[x1] + 2, ypos + y1, xpos + x2)
            @pull_win[x1] = cdkscreen.window.subwin(high, max + 2,
                                                    ypos + y2, xpos + x2)
            if @title_win[x1].nil? || @pull_win[x1].nil?
              destroy
              return nil
            end

            leftloc += @title_len[x] + 1
            @title_win[x1].keypad(true)
            @pull_win[x1].keypad(true)
          end
          @input_window = @title_win[@current_title]

          # Register this baby.
          cdkscreen.register(:Menu, self)
        end

        # This activates the CDK Menu
        def activate(actions)
          ret = 0

          # Draw in the screen.
          @screen.refresh

          # Display the menu titles.
          draw(@box)

          # Highlight the current title and window.
          draw_subwin

          # If the input string is empty this is an interactive activate.
          if actions.nil? || actions.empty?
            @input_window = @title_win[@current_title]

            # Start taking input from the keyboard.
            loop do
              input = getch([])

              # Inject the character into the widget.
              ret = inject(input)
              return ret if @exit_type != :EARLY_EXIT
            end
          else
            actions.each do |_action|
              return ret if @exit_type != :EARLY_EXIT
            end
          end

          # Set the exit type and return.
          set_exit_type(0)
          -1
        end

        def draw_title(item)
          Slithernix::Cdk::Draw.write_chtype(
            @title_win[item],
            0,
            0,
            @title[item],
            Slithernix::Cdk::HORIZONTAL,
            0,
            @title_len[item]
          )
        end

        def draw_item(item, offset)
          Slithernix::Cdk::Draw.write_chtype(
            @pull_win[@current_title],
            1,
            item + Slithernix::Cdk::Widget::Menu::TITLELINES - offset,
            @sublist[@current_title][item],
            Slithernix::Cdk::HORIZONTAL,
            0,
            @sublist_len[@current_title][item],
          )
        end

        # Highlight the current sub-menu item
        def select_item(item, offset)
          Slithernix::Cdk::Draw.write_chtype_attrib(
            @pull_win[@current_title],
            1,
            item + Slithernix::Cdk::Widget::Menu::TITLELINES - offset,
            @sublist[@current_title][item],
            @subtitle_attr,
            Slithernix::Cdk::HORIZONTAL,
            0,
            @sublist_len[@current_title][item],
          )
        end

        def within_submenu(step)
          next_item = Slithernix::Cdk::Widget::Menu.wrapped(
            @current_subtitle + step,
            @subsize[@current_title],
          )

          return unless next_item != @current_subtitle

          ts = 1 + @pull_win[@current_title].begy + @subsize[@current_title]
          ymax = @screen.window.maxy

          if ts >= ymax
            @current_subtitle = next_item
            draw_subwin
          else
            # Erase the old subtitle.
            draw_item(@current_subtitle, 0)

            # Set the values
            @current_subtitle = next_item

            # Draw the new sub-title.
            select_item(@current_subtitle, 0)

            @pull_win[@current_title].refresh
          end

          @input_window = @title_win[@current_title]
        end

        def across_submenus(step)
          next_item = Slithernix::Cdk::Widget::Menu.wrapped(
            @current_title + step,
            @menu_items,
          )

          return unless next_item != @current_title

          # Erase the menu sub-window.
          erase_subwin
          @screen.refresh

          # Set the values.
          @current_title = next_item
          @current_subtitle = 0

          # Draw the new menu sub-window.
          draw_subwin
          @input_window = @title_win[@current_title]
        end

        # Inject a character into the menu widget.
        def inject(input)
          pp_return = 1
          ret = -1
          complete = false

          # Set the exit type.
          set_exit_type(0)

          # Check if there is a pre-process function to be called.
          unless @pre_process_func.nil?
            # Call the pre-process function.
            pp_return = @pre_process_func.call(:Menu, self,
                                               @pre_process_data, input)
          end

          # Should we continue?

          if pp_return != 0
            # Check for key bindings.
            if check_bind(:Menu, input)
              complete = true
            else
              case input
              when Curses::KEY_LEFT
                across_submenus(-1)
              when Curses::KEY_RIGHT, Slithernix::Cdk::KEY_TAB
                across_submenus(1)
              when Curses::KEY_UP
                within_submenu(-1)
              when Curses::KEY_DOWN, ' '
                within_submenu(1)
              when Curses::KEY_ENTER, Slithernix::Cdk::KEY_RETURN
                cleanup_menu
                set_exit_type(input)
                @last_selection = (@current_title * 100) + @current_subtitle
                ret = @last_selection
                complete = true
              when Slithernix::Cdk::KEY_ESC
                cleanup_menu
                set_exit_type(input)
                @last_selection = -1
                ret = @last_selection
                complete = true
              when Curses::Error
                set_exit_type(input)
                complete = true
              when Slithernix::Cdk::REFRESH
                erase
                refresh
              end
            end

            # Should we call a post-process?
            if !complete && @post_process_func
              @post_process_func.call(:Menu, self, @post_process_data, input)
            end
          end

          set_exit_type(0) unless complete

          @result_data = ret
          ret
        end

        # Draw a menu item subwindow
        def draw_subwin
          high = @pull_win[@current_title].maxy - 2
          x0 = 0
          x1 = @subsize[@current_title]

          x1 = high if x1 > high

          if @current_subtitle >= x1
            x0 = @current_subtitle - x1 + 1
            x1 += x0
          end

          # Box the window
          @pull_win[@current_title]
          @pull_win[@current_title].box(
            Slithernix::Cdk::ACS_VLINE,
            Slithernix::Cdk::ACS_HLINE,
          )
          if @menu_pos == Slithernix::Cdk::BOTTOM
            @pull_win[@current_title].mvwaddch(
              @subsize[@current_title] + 1,
              0,
              Slithernix::Cdk::ACS_LTEE,
            )
          else
            @pull_win[@current_title].mvwaddch(0, 0, Slithernix::Cdk::ACS_LTEE)
          end

          # Draw the items.
          (x0...x1).each do |x|
            draw_item(x, x0)
          end

          select_item(@current_subtitle, x0)
          @pull_win[@current_title].refresh

          # Highlight the title.
          Slithernix::Cdk::Draw.write_chtype_attrib(
            @title_win[@current_title],
            0,
            0,
            @title[@current_title],
            @title_attr,
            Slithernix::Cdk::HORIZONTAL,
            0,
            @title_len[@current_title],
          )
          @title_win[@current_title].refresh
        end

        # Erase a menu item subwindow
        def erase_subwin
          Slithernix::Cdk.erase_curses_window(@pull_win[@current_title])

          # Redraw the sub-menu title.
          draw_title(@current_title)
          @title_win[@current_title].refresh
        end

        # Draw the menu.
        def draw(_box)
          # Draw in the menu titles.
          (0...@menu_items).each do |x|
            draw_title(x)
            @title_win[x].refresh
          end
        end

        # Move the menu to the given location.
        def move(xplace, yplace, relative, refresh_flag)
          windows = [@screen.window]
          (0...@menu_items).each do |x|
            windows << @title_win[x]
          end
          move_specific(
            xplace,
            yplace,
            relative,
            refresh_flag,
            windows,
            [],
          )
        end

        # Set the background attribute of the widget.
        def set_background_attr(attrib)
          (0...@menu_items).each do |x|
            @title_win[x].wbkgd(attrib)
            @pull_win[x].wbkgd(attrib)
          end
        end

        # Destroy a menu widget.
        def destroy
          # Clean up the windows
          (0...@menu_items).each do |x|
            Slithernix::Cdk.delete_curses_window(@title_win[x])
            Slithernix::Cdk.delete_curses_window(@pull_win[x])
          end

          # Clean the key bindings.
          clean_bindings(:Menu)

          # Unregister the widget
          Slithernix::Cdk::Screen.unregister(:Menu, self)
        end

        # Erase the menu widget from the screen.
        def erase
          return unless is_valid_widget?

          (0...@menu_items).each do |x|
            @title_win[x].erase
            @title_win[x].refresh
            @pull_win[x].erase
            @pull_win[x].refresh
          end
        end

        def set(menu_item, submenu_item, title_highlight, subtitle_highlight)
          set_current_item(menu_item, submenu_item)
          set_title_highlight(title_highlight)
          set_sub_title_highlight(subtitle_highlight)
        end

        # Set the current menu item to highlight.
        def set_current_item(menuitem, submenuitem)
          @current_title = Slithernix::Cdk::Widget::Menu.wrapped(
            menuitem,
            @menu_items,
          )

          @current_subtitle = Slithernix::Cdk::Widget::Menu.wrapped(
            submenuitem,
            @subsize[@current_title],
          )
        end

        def get_current_item(menu_item, submenu_item)
          menu_item << @current_title
          submenu_item << @current_subtitle
        end

        # Set the attribute of the menu titles.
        def set_title_highlight(highlight)
          @title_attr = highlight
        end

        def get_title_highlight
          @title_attr
        end

        # Set the attribute of the sub-title.
        def set_sub_title_highlight(highlight)
          @subtitle_attr = highlight
        end

        def get_sub_title_highlight
          @subtitle_attr
        end

        # Exit the menu.
        def cleanup_menu
          # Erase the sub-menu.
          erase_subwin
          @pull_win[@current_title].refresh

          # Refresh the screen.
          @screen.refresh
        end

        def focus
          draw_subwin
          @input_window = @title_win[@current_title]
        end

        # The "%" operator is simpler but does not handle negative values
        def self.wrapped(within, limit)
          if within.negative?
            within = limit - 1
          elsif within >= limit
            within = 0
          end
          within
        end
      end
    end
  end
end
