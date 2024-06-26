#!/usr/bin/env ruby
require_relative 'example'

class LabelExample < Example
  def LabelExample.parse_opts(opts, param)
    opts.banner = 'Usage: label_ex.rb [options]'

    param.x_value = Cdk::CENTER
    param.y_value = Cdk::CENTER
    param.box = true
    param.shadow = true
    super(opts, param)
  end

  # This program demonstrates the Cdk label widget.
  def LabelExample.main
    # Declare variables.
    mesg = []

    params = parse(ARGV)

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Cdk::Draw.initCDKColor

    # Set the labels up.
    mesg = [
        "</29/B>This line should have a yellow foreground and a blue background.",
        "</5/B>This line should have a white  foreground and a blue background.",
        "</26/B>This line should have a yellow foreground and a red  background.",
        "<C>This line should be set to whatever the screen default is."
    ]

    # Declare the labels.
    demo = Cdk::LABEL.new(cdkscreen,
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
    Cdk::Screen.endCDK
    #ExitProgram (EXIT_SUCCESS);
  end
end

LabelExample.main
