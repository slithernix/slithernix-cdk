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
  rescue StandardError => e
    raise Curses::Error, "Error in unctrl: #{e.message}"
  end

  class Window
    def mvwvline(y, x, ch, n)
      n.times do |i|
        setpos(y + i, x)
        addch(ch)
      end
    end

    def mvwhline(y, x, ch, n)
      setpos(y, x)

      n.times do |_i|
        addch(ch)
      end
    end

    def mvwaddch(y, x, ch)
      setpos(y, x)
      addch(ch)
    end

    def mvwdelch(y, x)
      setpos(y, x)
      delch
    end

    def mvwinsch(y, x, ch)
      setpos(y, x)
      insch(ch)
    end

    def mvinch(y, x)
      setpos(y, x)
      inch
    end
  end
end
