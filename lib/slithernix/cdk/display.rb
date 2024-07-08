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
        case type
        when :HCHAR, :HINT, :HMIXED, :LHCHAR, :LHMIXED, :UHCHAR, :UHMIXED
          true
        when :CHAR, :INT, :INVALID, :LCHAR, :LMIXED, :MIXED, :UCHAR, :UMIXED, :VIEWONLY
          false
        end
      end

      # Given a character input, check if it is allowed by the display type
      # and return the character to apply to the display, or ERR if not
      def self.filter_by_display_type(type, input)
        result = input
        if !Slithernix::Cdk.isChar(input)
          result = Curses::Error
        elsif %i[INT
                 HINT].include?(type) && !Slithernix::Cdk.digit?(result.chr)
          result = Curses::Error
        elsif %i[CHAR UCHAR LCHAR UHCHAR
                 LHCHAR].include?(type) && Slithernix::Cdk.digit?(result.chr)
          result = Curses::Error
        elsif type == :VIEWONLY
          result = ERR
        elsif %i[UCHAR UHCHAR UMIXED
                 UHMIXED].include?(type) && Slithernix::Cdk.alpha?(result.chr)
          result = result.chr.upcase.ord
        elsif %i[LCHAR LHCHAR LMIXED
                 LHMIXED].include?(type) && Slithernix::Cdk.alpha?(result.chr)
          result = result.chr.downcase.ord
        end

        result
      end
    end
  end
end
