# frozen_string_literal: true

module Slithernix
  module Cdk
    class Screen
      attr_accessor :exit_status,
                    :widget,
                    :widget_count,
                    :widget_limit,
                    :widget_focus,
                    :window

      NOEXIT = 0
      EXITOK = 1
      EXITCANCEL = 2

      def initialize(window = nil)
        window ||= Curses.init_screen
        Curses.curs_set(0)
        # initialization for the first time
        if Slithernix::Cdk::ALL_SCREENS.empty?
          # Set up basic curses settings.
          # #ifdef HAVE_SETLOCALE
          # setlocale (LC_ALL, "");
          # #endif

          Curses.noecho
          Curses.cbreak
        end

        Slithernix::Cdk::ALL_SCREENS << self
        @widget_count = 0
        @widget_limit = 2
        @widget = Array.new(@widget_limit, nil)
        @window = window
        @widget_focus = 0
      end

      # This registers a CDK widget with a screen.
      def register(cdktype, widget)
        if @widget_count + 1 >= @widget_limit
          @widget_limit += 2
          @widget_limit *= 2
          @widget.concat(Array.new(@widget_limit - @widget.size, nil))
        end

        return unless widget.validObjType(cdktype)

        set_screen_index(@widget_count, widget)
        @widget_count += 1
      end

      # This removes an widget from the CDK screen.
      def self.unregister(cdktype, widget)
        return unless widget.validObjType(cdktype) && widget.screen_index >= 0

        screen = widget.screen

        return if screen.nil?

        index = widget.screen_index
        widget.screen_index = -1

        # Resequence the widgets
        (index...screen.widget_count - 1).each do |x|
          screen.set_screen_index(x, screen.widget[x + 1])
        end

        if screen.widget_count <= 1
          # if no more widgets, remove the array
          screen.widget = []
          screen.widget_count = 0
          screen.widget_limit = 0
        else
          screen.widget[screen.widget_count] = nil
          screen.widget_count -= 1

          # Update the widget-focus
          if screen.widget_focus == index
            screen.widget_focus -= 1
            Traverse.set_focus_on_next_widget(screen)
          elsif screen.widget_focus > index
            screen.widget_focus -= 1
          end
        end
      end

      def set_screen_index(number, widg)
        widg.screen_index = number
        widg.screen = self
        @widget[number] = widg
      end

      def valid_index(n)
        n >= 0 && n < @widget_count
      end

      def swap_indices(n1, n2)
        return unless n1 != n2 && valid_index(n1) && valid_index(n2)

        o1 = @widget[n1]
        o2 = @widget[n2]
        set_screen_index(n1, o2)
        set_screen_index(n2, o1)

        if @widget_focus == n1
          @widget_focus = n2
        elsif @widget_focus == n2
          @widget_focus = n1
        end
      end

      # This 'brings' a CDK widget to the top of the stack.
      def self.raise_widget(cdktype, widget)
        return unless widget.validObjType(cdktype)

        screen = widget.screen
        screen.swap_indices(widget.screen_index, screen.widget_count - 1)
      end

      # This 'lowers' a widget.
      def self.lower_widget(cdktype, widget)
        return unless widget.validObjType(cdktype)

        widget.screen.swap_indices(widget.screen_index, 0)
      end

      # This pops up a message.
      def popup_label(mesg, count)
        # Create the label.
        popup = Slithernix::Cdk::Widget::Label.new(
          self,
          CENTER,
          CENTER,
          mesg,
          count,
          true,
          false,
        )

        old_state = Curses.curs_set(0)
        # Draw it on the screen
        popup.draw(true)

        # Wait for some input.
        popup.win.keypad(true)
        popup.getch([])

        # Kill it.
        popup.destroy

        # Clean the screen.
        Curses.curs_set(old_state)
        erase
        refresh
      end

      # This pops up a message
      def popup_label_attrib(mesg, count, _attrib)
        # Create the label.
        popup = Slithernix::Cdk::Widget::Label.new(
          self,
          CENTER,
          CENTER,
          mesg,
          count,
          true,
          false,
        )
        popup.setBackgroundAttrib

        old_state = Curses.curs_set(0)
        # Draw it on the screen)
        popup.draw(true)

        # Wait for some input
        popup.win.keypad(true)
        popup.getch([])

        # Kill it.
        popup.destroy

        # Clean the screen.
        Curses.curs_set(old_state)
        screen.erase
        screen.refresh
      end

      # This pops up a dialog box.
      def popup_dialog(mesg, mesg_count, buttons, button_count)
        # Create the dialog box.
        popup = Slithernix::Cdk::Widget::Dialog.new(
          self,
          Slithernix::Cdk::CENTER,
          Slithernix::Cdk::CENTER,
          mesg,
          mesg_count,
          buttons,
          button_count,
          Curses::A_REVERSE,
          true,
          true,
          false
        )

        # Activate the dialog box
        popup.draw(true)

        # Get the choice
        choice = popup.activate('')

        # Destroy the dialog box
        popup.destroy

        # Clean the screen.
        erase
        refresh

        choice
      end

      # This calls SCREEN.refresh, (made consistent with widget)
      def draw
        refresh
      end

      # Refresh one CDK window.
      # FIXME(original): this should be rewritten to use the panel library, so
      # it would not be necessary to touch the window to ensure that it covers
      # other windows.
      def self.refresh_window(win)
        win.touch
        win.refresh
      end

      # This refreshes all the widgets in the screen.
      def refresh
        focused = -1
        visible = -1

        Slithernix::Cdk::Screen.refresh_window(@window)

        # We erase all the invisible widgets, then only draw it all back, so
        # that the widgets can overlap, and the visible ones will always be
        # drawn after all the invisible ones are erased
        (0...@widget_count).each do |x|
          widg = @widget[x]
          if widg.validObjType(widg.widget_type)
            if widg.is_visible
              visible = x if visible.negative?
              focused = x if widg.has_focus && focused.negative?
            else
              widg.erase
            end
          end

          widg = @widget[x]

          next unless widg.validObjType(widg.widget_type)

          widg.has_focus = (x == focused)

          widg.draw(widg.box) if widg.is_visible
        end
      end

      # This clears all the widgets in the screen
      def erase
        # We just call the widget erase function
        (0...@widget_count).each do |x|
          widg = @widget[x]
          widg.erase if widg.validObjType(widg.widget_type)
        end

        # Refresh the screen.
        @window.refresh
      end

      # Destroy all the widgets on a screen
      def destroy_all_widgets
        (0...@widget_count).each do |x|
          widg = @widget[x]
          before = @widget_count

          next unless widg.validObjType(widg.widget_type)

          widg.erase
          widg.destroy
          x - (@widget_count - before)
        end
      end

      def destroy
        Slithernix::Cdk::ALL_SCREENS.delete(self)
      end

      def self.end_cdk
        Curses.echo
        Curses.nocbreak
        Curses.close_screen
      end
    end
  end
end
