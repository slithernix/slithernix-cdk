# frozen_string_literal: true

require_relative '../widget'
module Slithernix
  module Cdk
    class Widget
      class Scroller < Slithernix::Cdk::Widget
        def key_up
          if @list_size.positive?
            if @current_item.positive?
              if @current_high.zero?
                if @current_top.zero?
                  Slithernix::Cdk.beep
                else
                  @current_top -= 1
                  @current_item -= 1
                end
              else
                @current_item -= 1
                @current_high -= 1
              end
            else
              Slithernix::Cdk.beep
            end
          else
            Slithernix::Cdk.beep
          end
        end

        def key_down
          if @list_size.positive?
            if @current_item < @list_size - 1
              if @current_high == @view_size - 1
                if @current_top < @max_top_item
                  @current_top += 1
                  @current_item += 1
                else
                  Slithernix::Cdk.beep
                end
              else
                @current_item += 1
                @current_high += 1
              end
            else
              Slithernix::Cdk.beep
            end
          else
            Slithernix::Cdk.beep
          end
        end

        def key_left
          if @list_size.positive?
            if @left_char.zero?
              Slithernix::Cdk.beep
            else
              @left_char -= 1
            end
          else
            Slithernix::Cdk.beep
          end
        end

        def key_right
          if @list_size.positive?
            if @left_char >= @max_left_char
              Slithernix::Cdk.beep
            else
              @left_char += 1
            end
          else
            Slithernix::Cdk.beep
          end
        end

        def key_ppage
          if @list_size.positive?
            if @current_top.positive?
              if @current_top >= @view_size - 1
                @current_top -= @view_size - 1
                @current_item -= @view_size - 1
              else
                key_home
              end
            else
              Slithernix::Cdk.beep
            end
          else
            Slithernix::Cdk.beep
          end
        end

        def key_npage
          if @list_size.positive?
            if @current_top < @max_top_item
              if @current_top + @view_size - 1 <= @max_top_item
                @current_top += @view_size - 1
                @current_item += @view_size - 1
              else
                @current_top = @max_top_item
                @current_item = @last_item
                @current_high = @view_size - 1
              end
            else
              Slithernix::Cdk.beep
            end
          else
            Slithernix::Cdk.beep
          end
        end

        def key_home
          @current_top = 0
          @current_item = 0
          @current_high = 0
        end

        def key_end
          if @max_top_item == -1
            @current_top = 0
            @current_item = @last_item - 1
          else
            @current_top = @max_top_item
            @current_item = @last_item
          end
          @current_high = @view_size - 1
        end

        def available_width
          @box_width - (2 * @border_size)
        end

        def focus
          draw_list(@box)
        end

        def get_current_item
          @current_item
        end

        def max_view_size
          @box_height - ((2 * @border_size) + @title_lines)
        end

        def set_current_item(item)
          set_position(item)
        end

        def set_position(item)
          if item <= 0
            key_home
          elsif item > @list_size - 1
            @current_top = @max_top_item
            @current_item = @list_size - 1
            @current_high = @view_size - 1
          elsif item >= @current_top && item < @current_top + @view_size
            @current_item = item
            @current_high = item - @current_top
          else
            @current_top = item - (@view_size - 1)
            @current_item = item
            @current_high = @view_size - 1
          end
        end

        # Set variables that depend upon the list_size
        def set_view_size(list_size)
          @view_size = max_view_size
          @list_size = list_size
          @last_item = list_size - 1
          @max_top_item = list_size - @view_size

          if list_size < @view_size
            @view_size = list_size
            @max_top_item = 0
          end

          @step = 1
          @toggle_size = 1

          if @list_size.positive? && max_view_size.positive?
            @step = 1.0 * max_view_size / @list_size
            @toggle_size = @list_size > max_view_size ? 1 : @step.ceil
          end
        end

        def unfocus
          draw_list(@box)
        end

        def update_view_width(widest)
          @max_left_char = widest - available_width
          @max_left_char = 0 if @box_width > widest
          @max_left_char
        end

        def widest_item
          @max_left_char + available_width
        end
      end
    end
  end
end
