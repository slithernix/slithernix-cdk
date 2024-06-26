#!/usr/bin/env ruby
require_relative 'example'

class LowerCDKObjectExample < Example
  def LowerCDKObjectExample.parse_opts(opts, param)
    opts.banner = 'Usage: lowerCDKObject_ex.rb [options]'

    param.x_value = Cdk::CENTER
    param.y_value = Cdk::BOTTOM
    param.box = false
    param.shadow = false
    super(opts, param)
  end

  def LowerCDKObjectExample.main
    # Declare variables.
    params = parse(ARGV)

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Cdk::Screen.new(curses_win)

    mesg1 = [
        "label1 label1 label1 label1 label1 label1 label1",
        "label1 label1 label1 label1 label1 label1 label1",
        "label1 label1 label1 label1 label1 label1 label1",
        "label1 label1 label1 label1 label1 label1 label1",
        "label1 label1 label1 label1 label1 label1 label1",
        "label1 label1 label1 label1 label1 label1 label1",
        "label1 label1 label1 label1 label1 label1 label1",
        "label1 label1 label1 label1 label1 label1 label1",
        "label1 label1 label1 label1 label1 label1 label1",
        "label1 label1 label1 label1 label1 label1 label1"
    ]
    label1 = Cdk::LABEL.new(cdkscreen, 8, 5, mesg1, 10, true, false)

    mesg2 = [
        "label2 label2 label2 label2 label2 label2 label2",
        "label2 label2 label2 label2 label2 label2 label2",
        "label2 label2 label2 label2 label2 label2 label2",
        "label2 label2 label2 label2 label2 label2 label2",
        "label2 label2 label2 label2 label2 label2 label2",
        "label2 label2 label2 label2 label2 label2 label2",
        "label2 label2 label2 label2 label2 label2 label2",
        "label2 label2 label2 label2 label2 label2 label2",
        "label2 label2 label2 label2 label2 label2 label2",
        "label2 label2 label2 label2 label2 label2 label2"
    ]
    label2 = Cdk::LABEL.new(cdkscreen, 14, 9, mesg2, 10, true, false)

    mesg = ["</B>1<!B> - lower </U>label1<!U>, </B>2<!B> - lower "]
    mesg[0] << "</U>label2<!U>, </B>q<!B> - </U>quit<!U>"
    instruct = Cdk::LABEL.new(cdkscreen, params.x_value, params.y_value,
                              mesg, 1, params.box, params.shadow)

    cdkscreen.refresh

    while (ch = STDIN.getc.chr) != 'q'
      case ch
      when '1'
        Cdk::Screen.lowerCDKObject(:LABEL, label1)
      when '2'
        Cdk::Screen.lowerCDKObject(:LABEL, label2)
      else
        next
      end
      cdkscreen.refresh
    end

    # Clean up
    label1.destroy
    label2.destroy
    instruct.destroy
    cdkscreen.destroy
    Cdk::Screen.endCDK
    #ExitProgram (EXIT_SUCCESS);
  end
end

LowerCDKObjectExample.main
