# frozen_string_literal: true

require_relative 'scale'

module Slithernix
  module Cdk
    class Widget
      class UScale < Slithernix::Cdk::Widget::Scale
        # The original UScale handled unsigned values.
        # Since Ruby's typing is different this is really just SCALE
        # but is nice it's nice to have this for compatibility/completeness
        # sake.
      end
    end
  end
end
