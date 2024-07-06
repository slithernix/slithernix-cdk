#!/usr/bin/env ruby
require_relative 'example'

class LabelExample < Example
  def self.parse_opts(opts, param)
    opts.banner = 'Usage: label_ex.rb [options]'

    param.x_value = Slithernix::Cdk::CENTER
    param.y_value = Slithernix::Cdk::CENTER
    param.box = true
    param.shadow = true
    super
  end

  # This program demonstrates the Cdk label widget.
  def self.main
    # Declare variables.
    mesg = []

    params = parse(ARGV)

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.initCDKColor

    # Set the labels up.
    mesg = [
      '</29/B>This line should have a yellow foreground and a blue background.',
      '</5/B>This line should have a white  foreground and a blue background.',
      '</26/B>This line should have a yellow foreground and a red  background.',
      '<C>This line should be set to whatever the screen default is.'
    ]

    # Declare the labels.
    demo = Slithernix::Cdk::Widget::Label.new(cdkscreen,
                                              params.x_value, params.y_value, mesg, 4,
                                              params.box, params.shadow)

    # if (demo == 0)
    # {
    #   /* Clean up the memory.
    #   destroyCDKScreen (cdkscreen);
    #
    #   # End curses...
    #   endCDK ();
    #
    #   printf ("Cannot create the label. Is the window too small?\n");
    #   ExitProgram (EXIT_FAILURE);
    # }

    # Draw the CDK screen.
    cdkscreen.refresh
    demo.wait(' ')

    # Clean up
    demo.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    # ExitProgram (EXIT_SUCCESS);
  end
end

LabelExample.main
