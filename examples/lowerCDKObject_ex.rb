#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'example'

class LowerCDKObjectExample < Example
  def self.parse_opts(opts, param)
    opts.banner = 'Usage: lowerCDKObject_ex.rb [options]'

    param.x_value = Slithernix::Cdk::CENTER
    param.y_value = Slithernix::Cdk::BOTTOM
    param.box = false
    param.shadow = false
    super
  end

  def self.main
    # Declare variables.
    params = parse(ARGV)

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    mesg1 = [
      'label1 label1 label1 label1 label1 label1 label1',
      'label1 label1 label1 label1 label1 label1 label1',
      'label1 label1 label1 label1 label1 label1 label1',
      'label1 label1 label1 label1 label1 label1 label1',
      'label1 label1 label1 label1 label1 label1 label1',
      'label1 label1 label1 label1 label1 label1 label1',
      'label1 label1 label1 label1 label1 label1 label1',
      'label1 label1 label1 label1 label1 label1 label1',
      'label1 label1 label1 label1 label1 label1 label1',
      'label1 label1 label1 label1 label1 label1 label1'
    ]
    label1 = Slithernix::Cdk::Widget::Label.new(cdkscreen, 8, 5, mesg1, 10,
                                                true, false)

    mesg2 = [
      'label2 label2 label2 label2 label2 label2 label2',
      'label2 label2 label2 label2 label2 label2 label2',
      'label2 label2 label2 label2 label2 label2 label2',
      'label2 label2 label2 label2 label2 label2 label2',
      'label2 label2 label2 label2 label2 label2 label2',
      'label2 label2 label2 label2 label2 label2 label2',
      'label2 label2 label2 label2 label2 label2 label2',
      'label2 label2 label2 label2 label2 label2 label2',
      'label2 label2 label2 label2 label2 label2 label2',
      'label2 label2 label2 label2 label2 label2 label2'
    ]
    label2 = Slithernix::Cdk::Widget::Label.new(cdkscreen, 14, 9, mesg2, 10,
                                                true, false)

    mesg = ['</B>1<!B> - lower </U>label1<!U>, </B>2<!B> - lower '.dup]
    mesg[0] << '</U>label2<!U>, </B>q<!B> - </U>quit<!U>'
    instruct = Slithernix::Cdk::Widget::Label.new(cdkscreen, params.x_value, params.y_value,
                                                  mesg, 1, params.box, params.shadow)

    cdkscreen.refresh

    while (ch = $stdin.getc.chr) != 'q'
      case ch
      when '1'
        Slithernix::Cdk::Screen.lower_widget(:Label, label1)
      when '2'
        Slithernix::Cdk::Screen.lower_widget(:Label, label2)
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
    Slithernix::Cdk::Screen.end_cdk
    # ExitProgram (EXIT_SUCCESS);
  end
end

LowerCDKObjectExample.main
