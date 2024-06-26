require_relative 'f_scale'

module Slithernix
  module Cdk
    class Widget
      class DScale < Slithernix::Cdk::Widget::FScale
        # The original DScale handled unsigned values.
        # Since Ruby's typing is different this is really just FSCALE
        # but is nice it's nice to have this for compatibility/completeness
        # sake.
      end
    end
  end
end
