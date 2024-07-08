#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'example'

class RaiseCDKObjectExample < Example
  def self.MY_LABEL(widg)
    widg.screen_index | 0x30 | Curses::A_UNDERLINE | Curses::A_BOLD
  end

  def self.parse_opts(opts, param)
    opts.banner = 'Usage: raise_widget_ex.rb [options]'

    param.x_value = Slithernix::Cdk::CENTER
    param.y_value = Slithernix::Cdk::BOTTOM
    param.box = true
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
    label1 = Slithernix::Cdk::Widget::Label.new(cdkscreen, 10, 4, mesg1, 10,
                                                true, false)
    label1.set_upper_left_corner_char('1'.ord | Curses::A_BOLD)

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
    label2 = Slithernix::Cdk::Widget::Label.new(cdkscreen, 8, 8, mesg2, 10,
                                                true, false)
    label2.set_upper_left_corner_char('2'.ord | Curses::A_BOLD)

    mesg3 = [
      'label3 label3 label3 label3 label3 label3 label3',
      'label3 label3 label3 label3 label3 label3 label3',
      'label3 label3 label3 label3 label3 label3 label3',
      'label3 label3 label3 label3 label3 label3 label3',
      'label3 label3 label3 label3 label3 label3 label3',
      'label3 label3 label3 label3 label3 label3 label3',
      'label3 label3 label3 label3 label3 label3 label3',
      'label3 label3 label3 label3 label3 label3 label3',
      'label3 label3 label3 label3 label3 label3 label3',
      'label3 label3 label3 label3 label3 label3 label3'
    ]
    label3 = Slithernix::Cdk::Widget::Label.new(cdkscreen, 6, 12, mesg3, 10,
                                                true, false)
    label3.set_upper_left_corner_char('3'.ord | Curses::A_BOLD)

    mesg4 = [
      'label4 label4 label4 label4 label4 label4 label4',
      'label4 label4 label4 label4 label4 label4 label4',
      'label4 label4 label4 label4 label4 label4 label4',
      'label4 label4 label4 label4 label4 label4 label4',
      'label4 label4 label4 label4 label4 label4 label4',
      'label4 label4 label4 label4 label4 label4 label4',
      'label4 label4 label4 label4 label4 label4 label4',
      'label4 label4 label4 label4 label4 label4 label4',
      'label4 label4 label4 label4 label4 label4 label4',
      'label4 label4 label4 label4 label4 label4 label4'
    ]
    label4 = Slithernix::Cdk::Widget::Label.new(cdkscreen, 4, 16, mesg4, 10,
                                                true, false)
    label4.set_upper_left_corner_char('4'.ord | Curses::A_BOLD)

    mesg = ['</B>#<!B> - raise </U>label#<!U>, </B>r<!B> - </U>redraw<!U>, '.dup]
    mesg[0] << '</B>q<!B> - </U>quit<!U>'
    instruct = Slithernix::Cdk::Widget::Label.new(
      cdkscreen,
      params.x_value,
      params.y_value,
      mesg,
      1,
      params.box,
      params.shadow
    )

    instruct.set_upper_left_corner_char(' '.ord | Curses::A_NORMAL)
    instruct.set_upper_right_corner_char(' '.ord | Curses::A_NORMAL)
    instruct.set_lower_left_corner_char(' '.ord | Curses::A_NORMAL)
    instruct.set_vertical_line_char(' '.ord | Curses::A_NORMAL)
    instruct.set_horizontal_line_char(' '.ord | Curses::A_NORMAL)

    label1.set_lower_right_corner_char(MY_LABEL(label1))
    label2.set_lower_right_corner_char(MY_LABEL(label2))
    label3.set_lower_right_corner_char(MY_LABEL(label3))
    label4.set_lower_right_corner_char(MY_LABEL(label4))
    instruct.set_lower_right_corner_char(MY_LABEL(instruct))

    cdkscreen.refresh

    while (ch = $stdin.getc.chr) != 'q'
      case ch
      when '1'
        Slithernix::Cdk::Screen.raise_widget(:Label, label1)
      when '2'
        Slithernix::Cdk::Screen.raise_widget(:Label, label2)
      when '3'
        Slithernix::Cdk::Screen.raise_widget(:Label, label3)
      when '4'
        Slithernix::Cdk::Screen.raise_widget(:Label, label4)
      when 'r'
        cdkscreen.refresh
      else
        next
      end

      label1.set_lower_right_corner_char(MY_LABEL(label1))
      label2.set_lower_right_corner_char(MY_LABEL(label2))
      label3.set_lower_right_corner_char(MY_LABEL(label3))
      label4.set_lower_right_corner_char(MY_LABEL(label4))
      instruct.set_lower_right_corner_char(MY_LABEL(instruct))
      cdkscreen.refresh
    end

    # Clean up
    label1.destroy
    label2.destroy
    label3.destroy
    label4.destroy
    instruct.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.end_cdk
    # ExitProgram (EXIT_SUCCESS);
  end
end

RaiseCDKObjectExample.main
