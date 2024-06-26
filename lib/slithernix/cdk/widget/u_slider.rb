require_relative 'slider'

module Slithernix
  module Cdk
    class Widget
      class USlider < Slithernix::Cdk::Widget::Slider
        # The original USlider handled unsigned values.
        # Since Ruby's typing is different this is really just SLIDER
        # but is nice it's nice to have this for compatibility/completeness
        # sake.
      end
    end
  end
end
