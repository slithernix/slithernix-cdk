# I hate this but, whatever
module Curses
  def self.napms(ms)
    sleep(ms / 1000.0)
  end

  def self.unctrl(ch)
    raise Curses::Error, 'Input is not an Integer' unless ch.is_a?(Integer)
    raise Curses::Error, 'Input is out of ASCII range' if ch < 0 || ch > 127

    if (32..126).include?(ch)
      ch.chr
    elsif ch == 127
      '^?'
    else
      "^#{(ch + 64).chr}"
    end
  rescue => e
    raise Curses::Error, "Error in unctrl: #{e.message}"
  end

  class Window
    def mvwvline(y, x, ch, n)
      n.times do |i|
        self.setpos(y + i, x)
        self.addch(ch)
      end
    end

    def mvwhline(y, x, ch, n)
      self.setpos(y, x)

      n.times do |i|
        self.addch(ch)
      end
    end

    def mvwaddch(y, x, ch)
      self.setpos(y, x)
      self.addch(ch)
    end

    def mvwdelch(y, x)
      self.setpos(y, x)
      self.delch()
    end

    def mvwinsch(y, x, ch)
      self.setpos(y, x)
      self.insch(ch)
    end

    def mvinch(y, x)
      self.setpos(y, x)
      self.inch
    end
  end
end
