module Slithernix
  module Cdk
    module Traverse
      def self.resetCDKScreen(screen)
        refreshDataCDKScreen(screen)
      end

      def self.exitOKCDKScreen(screen)
        screen.exit_status = Slithernix::Cdk::Screen::EXITOK
      end

      def self.exitCancelCDKScreen(screen)
        screen.exit_status = Slithernix::Cdk::Screen::EXITCANCEL
      end

      def self.exitOKCDKScreenOf(widg)
        exitOKCDKScreen(widg.screen)
      end

      def self.exitCancelCDKScreenOf(widg)
        exitCancelCDKScreen(widg.screen)
      end

      def self.resetCDKScreenOf(widg)
        resetCDKScreen(widg.screen)
      end

      # Returns the widget on which the focus lies.
      def self.getCDKFocusCurrent(screen)
        result = nil
        n = screen.widget_focus

        if n >= 0 && n < screen.widget_count
          result = screen.widget[n]
        end

        return result
      end

      # Set focus to the next widget, returning it.
      def self.setCDKFocusNext(screen)
        result = nil
        curwidg = nil
        n = getFocusIndex(screen)
        first = n

        while true
          n+= 1
          if n >= screen.widget_count
            n = 0
          end
          curwidg = screen.widget[n]
          if !(curwidg.nil?) && curwidg.accepts_focus
            result = curwidg
            break
          else
            if n == first
              break
            end
          end
        end

        setFocusIndex(screen, if !(result.nil?) then n else -1 end)
        return result
      end

      # Set focus to the previous widget, returning it.
      def self.setCDKFocusPrevious(screen)
        result = nil
        curwidg = nil
        n = getFocusIndex(screen)
        first = n

        while true
          n -= 1
          if n < 0
            n = screen.widget_count - 1
          end
          curwidg = screen.widget[n]
          if !(curwidg.nil?) && curwidg.accepts_focus
            result = curwidg
            break
          elsif n == first
            break
          end
        end

        setFocusIndex(screen, if !(result.nil?) then n else -1 end)
        return result
      end

      # Set focus to a specific widget, returning it.
      # If the widget cannot be found, return nil.
      def self.setCDKFocusCurrent(screen, newwidg)
        result = nil
        curwidg = nil
        n = getFocusIndex(screen)
        first = n

        while true
          n += 1
          if n >= screen.widget_count
            n = 0
          end

          curwidg = screen.widget[n]
          if curwidg == newwidg
            result = curwidg
            break
          elsif n == first
            break
          end
        end

        setFocusIndex(screen, if !(result.nil?) then n else -1 end)
        return result
      end

      # Set focus to the first widget in the screen.
      def self.setCDKFocusFirst(screen)
        setFocusIndex(screen, screen.widget_count - 1)
        return switchFocus(setCDKFocusNext(screen), nil)
      end

      # Set focus to the last widget in the screen.
      def self.setCDKFocusLast(screen)
        setFocusIndex(screen, 0)
        return switchFocus(setCDKFocusPrevious(screen), nil)
      end

      def self.traverseCDKOnce(screen, curwidg, key_code,
          function_key, func_menu_key)
        case key_code
        when Curses::KEY_BTAB
          switchFocus(setCDKFocusPrevious(screen), curwidg)
        when Slithernix::Cdk::KEY_TAB
          switchFocus(setCDKFocusNext(screen), curwidg)
        when Slithernix::Cdk.KEY_F(10)
          # save data and exit
          exitOKCDKScreen(screen)
        when Slithernix::Cdk.CTRL('X')
          exitCancelCDKScreen(screen)
        when Slithernix::Cdk.CTRL('R')
          # reset data to defaults
          resetCDKScreen(screen)
          setFocus(curwidg)
        when Slithernix::Cdk::REFRESH
          # redraw screen
          screen.refresh
          setFocus(curwidg)
        else
          # not everyone wants menus, so we make them optional here
          if !(func_menu_key.nil?) &&
              (func_menu_key.call(key_code, function_key))
            # find and enable drop down menu
            screen.widget.each do |widget|
              if !(widget.nil?) && widget.widget_type == :Menu
                self.handleMenu(screen, widget, curwidg)
              end
            end
          else
            curwidg.inject(key_code)
          end
        end
      end

      # Traverse the widget on a screen.
      def self.traverseCDKScreen(screen)
        result = 0
        curwidg = setCDKFocusFirst(screen)

        unless curwidg.nil?
          refreshDataCDKScreen(screen)

          screen.exit_status = Slithernix::Cdk::Screen::NOEXIT

          while !((curwidg = getCDKFocusCurrent(screen)).nil?) &&
              screen.exit_status == Slithernix::Cdk::Screen::NOEXIT
            function = []
            key = curwidg.getch(function)

            # TODO look at more direct way to do this
            check_menu_key = lambda do |key_code, function_key|
              self.checkMenuKey(key_code, function_key)
            end


            self.traverseCDKOnce(screen, curwidg, key,
                function[0], check_menu_key)
          end

          if screen.exit_status == Slithernix::Cdk::Screen::EXITOK
            saveDataCDKScreen(screen)
            result = 1
          end
        end
        return result
      end

      private

      def self.limitFocusIndex(screen, value)
        if value >= screen.widget_count || value < 0
          0
        else
          value
        end
      end

      def self.getFocusIndex(screen)
        return limitFocusIndex(screen, screen.widget_focus)
      end

      def self.setFocusIndex(screen, value)
        screen.widget_focus = limitFocusIndex(screen, value)
      end

      def self.unsetFocus(widg)
        Curses.curs_set(0)
        unless widg.nil?
          widg.has_focus = false
          widg.unfocus
        end
      end

      def self.setFocus(widg)
        unless widg.nil?
          widg.has_focus = true
          widg.focus
        end
        Curses.curs_set(1)
      end

      def self.switchFocus(newwidg, oldwidg)
        if oldwidg != newwidg
          self.unsetFocus(oldwidg)
          self.setFocus(newwidg)
        end
        return newwidg
      end

      def self.checkMenuKey(key_code, function_key)
        key_code == Slithernix::Cdk::KEY_ESC && !function_key
      end

      def self.handleMenu(screen, menu, oldwidg)
        done = false

        switchFocus(menu, oldwidg)
        while !done
          key = menu.getch([])

          case key
          when Slithernix::Cdk::KEY_TAB
            done = true
          when Slithernix::Cdk::KEY_ESC
            # cleanup the menu
            menu.inject(key)
            done = true
          else
            done = (menu.inject(key) >= 0)
          end
        end

        if (newwidg = self.getCDKFocusCurrent(screen)).nil?
          newwidg = self.setCDKFocusNext(screen)
        end

        return switchFocus(newwidg, menu)
      end

      # Save data in widget on a screen
      def self.saveDataCDKScreen(screen)
        screen.widget.each do |widget|
          unless widget.nil?
            widget.saveData
          end
        end
      end

      # Refresh data in widget on a screen
      def self.refreshDataCDKScreen(screen)
        screen.widget.each do |widget|
          unless widget.nil?
            widget.refreshData
          end
        end
      end
    end
  end
end