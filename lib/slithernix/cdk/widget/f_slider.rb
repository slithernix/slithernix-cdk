# frozen_string_literal: true

require_relative 'slider'

module Slithernix
  module Cdk
    class Widget
      class FSlider < Slithernix::Cdk::Widget::Slider
        def initialize(cdkscreen, xplace, yplace, title, label, filler,
                       field_width, start, low, high, inc, fast_inc, digits, box, shadow)
          @digits = digits
          super(
            cdkscreen,
            xplace,
            yplace,
            title,
            label,
            filler,
            field_width,
            start,
            low,
            high,
            inc,
            fast_inc,
            box,
            shadow
          )
        end

        # This draws the widget.
        def draw_field
          step = 1.0 * @field_width / (@high - @low)

          # Determine how many filler characters need to be drawn.
          filler_characters = (@current - @low) * step

          @field_win.erase

          # Add the character to the window.
          (0...filler_characters).each do |x|
            @field_win.mvwaddch(0, x, @filler)
          end

          # Draw the value in the field.
          digits = [@digits, 30].min
          format = format('%%.%if', digits)
          temp = format(format, @current)

          Slithernix::Cdk::Draw.write_char_attrib(
            @field_win,
            @field_width,
            0,
            temp,
            Curses::A_NORMAL,
            Slithernix::Cdk::HORIZONTAL,
            0,
            temp.size,
          )

          move_to_edit_position(@field_edit)
          @field_win.refresh
        end

        def formatted_size(value)
          digits = [@digits, 30].min
          format = format('%%.%if', digits)
          temp = format(format, value)
          temp.size
        end

        def set_digits(digits)
          @digits = [0, digits].max
        end

        def get_digits
          @digits
        end

        def scan_fmt
          '%g%c'
        end
      end
    end
  end
end
