#!/usr/bin/env ruby
require_relative '../lib/slithernix/cdk'

class StopSign
  def self.main
    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.initCDKColor

    # Set the labels up.
    mesg = [
      '<C><#HL(40)>',
      '<C>Press </B/16>r<!B!16> for the </B/16>red light',
      '<C>Press </B/32>y<!B!32> for the </B/32>yellow light',
      '<C>Press </B/24>g<!B!24> for the </B/24>green light',
      '<C><#HL(40)>',
    ]
    sign = [
      ' <#DI> ',
      ' <#DI> ',
      ' <#DI> ',
    ]

    # Declare the labels.
    title = Slithernix::Cdk::Widget::Label.new(cdkscreen, Slithernix::Cdk::CENTER, Slithernix::Cdk::TOP,
                                               mesg, 5, false, false)
    stop_sign = Slithernix::Cdk::Widget::Label.new(cdkscreen, Slithernix::Cdk::CENTER, Slithernix::Cdk::CENTER,
                                                   sign, 3, true, true)

    # Do this until they hit q or escape.
    loop do
      title.draw(false)
      stop_sign.draw(true)

      key = stop_sign.getch([])
      if [Slithernix::Cdk::KEY_ESC, 'q', 'Q'].include?(key)
        break
      elsif %w[r R].include?(key)
        sign[0] = ' </B/16><#DI> '
        sign[1] = ' o '
        sign[2] = ' o '
      elsif %w[y Y].include?(key)
        sign[0] = ' o '
        sign[1] = ' </B/32><#DI> '
        sign[2] = ' o '
      elsif %w[g G].include?(key)
        sign[0] = ' o '
        sign[1] = ' o '
        sign[2] = ' </B/24><#DI> '
      end

      # Set the contents of the label and re-draw it.
      stop_sign.set(sign, 3, true)
    end

    # Clean up
    title.destroy
    stop_sign.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    # ExitProgram (EXIT_SUCCESS);
  end
end

StopSign.main
