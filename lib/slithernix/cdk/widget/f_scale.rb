# frozen_string_literal: true

require_relative 'scale'

module Slithernix
  module Cdk
    class Widget
      class FScale < Slithernix::Cdk::Widget::Scale
        def initialize(cdkscreen, xplace, yplace, title, label, field_attr, field_width, start, low, high, inc, fast_inc, digits, box, shadow)
          @digits = digits
          super(
            cdkscreen,
            xplace,
            yplace,
            title,
            label,
            field_attr,
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

        def draw_field
          @field_win.erase

          # Draw the value in the field.
          digits = [@digits, 30].min
          format = format('%%.%if', digits)
          temp = format(format, @current)

          Slithernix::Cdk::Draw.write_char_attrib(
            @field_win,
            @field_width - temp.size - 1,
            0,
            temp,
            @field_attr,
            Slithernix::Cdk::HORIZONTAL,
            0,
            temp.size,
          )

          moveToEditPosition(@field_edit)
          @field_win.refresh
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
