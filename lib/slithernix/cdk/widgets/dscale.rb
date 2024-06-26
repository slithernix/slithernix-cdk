require_relative 'fscale'

module Cdk
  class DSCALE < Cdk::FSCALE
    # The original DScale handled unsigned values.
    # Since Ruby's typing is different this is really just FSCALE
    # but is nice it's nice to have this for compatibility/completeness
    # sake.
    def object_type
      :DSCALE
    end
  end
end
