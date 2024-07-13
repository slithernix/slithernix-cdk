# frozen_string_literal: true

module Slithernix
  module Cdk
    module Display
      # Given a string, returns the equivalent display type
      def self.char_to_display_type(string)
        table = {
          'CHAR' => :CHAR,
          'HCHAR' => :HCHAR,
          'INT' => :INT,
          'HINT' => :HINT,
          'UCHAR' => :UCHAR,
          'LCHAR' => :LCHAR,
          'UHCHAR' => :UHCHAR,
          'LHCHAR' => :LHCHAR,
          'MIXED' => :MIXED,
          'HMIXED' => :HMIXED,
          'UMIXED' => :UMIXED,
          'LMIXED' => :LMIXED,
          'UHMIXED' => :UHMIXED,
          'LHMIXED' => :LHMIXED,
          'VIEWONLY' => :VIEWONLY,
          0 => :INVALID
        }

        if table.include?(string)
          table[string]
        else
          :INVALID
        end
      end

      # Tell if a display type is "hidden"
      def self.is_hidden_display_type?(type)
        hidden_types = %i[
          HCHAR HINT HMIXED LHCHAR LHMIXED UHCHAR UHMIXED
        ]
        hidden_types.include?(type)
      end

      # Given a character input, check if it is allowed by the display type
      # and return the character to apply to the display, or ERR if not
      def self.filter_by_display_type(type, input)
        return Curses::Error unless Slithernix::Cdk.is_char?(input)

        case type
        when :INT, :HINT
          Slithernix::Cdk.digit?(input.chr) ? input : Curses::Error
        when :CHAR, :UCHAR, :LCHAR, :UHCHAR, :LHCHAR
          Slithernix::Cdk.digit?(input.chr) ? Curses::Error : input
        when :VIEWONLY
          ERR
        when :UCHAR, :UHCHAR, :UMIXED, :UHMIXED
          Slithernix::Cdk.alpha?(input.chr) ? input.chr.upcase.ord : input
        when :LCHAR, :LHCHAR, :LMIXED, :LHMIXED
          Slithernix::Cdk.alpha?(input.chr) ? input.chr.downcase.ord : input
        else
          input
        end
      end
    end
  end
end
