require_relative 'slider'

module Cdk
  class USLIDER < Cdk::SLIDER
    # The original USlider handled unsigned values.
    # Since Ruby's typing is different this is really just SLIDER
    # but is nice it's nice to have this for compatibility/completeness
    # sake.

    def object_type
      :USLIDER
    end
  end
end
