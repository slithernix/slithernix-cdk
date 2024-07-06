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
        def drawField
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

          Slithernix::Cdk::Draw.writeCharAttrib(
            @field_win,
            @field_width,
            0,
            temp,
            Curses::A_NORMAL,
            Slithernix::Cdk::HORIZONTAL,
            0,
            temp.size,
          )

          moveToEditPosition(@field_edit)
          @field_win.refresh
        end

        def formattedSize(value)
          digits = [@digits, 30].min
          format = format('%%.%if', digits)
          temp = format(format, value)
          temp.size
        end

        def setDigits(digits)
          @digits = [0, digits].max
        end

        def getDigits
          @digits
        end

        def SCAN_FMT
          '%g%c'
        end
      end
    end
  end
end
