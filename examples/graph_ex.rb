#!/usr/bin/env ruby
require_relative 'example'

class GraphExample < CLIExample
  def GraphExample.parse_opts(opts, params)
    opts.banner = 'Usage: graph_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = Cdk::CENTER
    params.y_value = Cdk::CENTER
    params.h_value = 10
    params.w_value = 20

    super(opts, params)
  end

  def GraphExample.main
    params = parse(ARGV)

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Cdk::Draw.initCDKColor

    # Create the graph values.
    values = [10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
    count = 10
    title = "<C>Test Graph"
    xtitle = "<C>X AXIS TITLE"
    ytitle = "<C>Y AXIS TITLE"
    graph_chars = "0123456789"

    # Create the label values.
    mesg = ["Press any key when done viewing the graph."]

    graph = Cdk::GRAPH.new(cdkscreen, params.x_value, params.y_value,
                           params.h_value, params.w_value, title, xtitle, ytitle)

    # Is the graph null?
    if graph.nil?
      cdkscreen.destroy
      Cdk::Screen.endCDK

      puts "Cannot make the graph widget.  Is the window too small?"
      exit #EXIT_FAILURE
    end

    # Create the label widget.
    pausep = Cdk::LABEL.new(cdkscreen, Cdk::CENTER, Cdk::BOTTOM, mesg, 1,
                            true, false)

    if pausep.nil?
      graph.destroy
      cdkscreen.destroy
      Cdk::Screen.endCDK

      puts "Cannot make the label widget. Is the window too small?"
      exit  # EXIT_FAILURE
    end

    # Set the graph values
    graph.set(values, count, graph_chars, false, :PLOT)

    # Draw the screen.
    cdkscreen.refresh
    graph.draw(false)
    pausep.draw(true)

    # Pause until the user says so...
    pausep.wait(0)

    # Clean up
    graph.destroy
    pausep.destroy
    cdkscreen.destroy
    Cdk::Screen.endCDK
    exit  # EXIT_SUCCESS
  end
end

GraphExample.main
