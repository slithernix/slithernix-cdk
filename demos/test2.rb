#!/usr/bin/env ruby
require 'curses'

# Initialize curses
Curses.init_screen
win = Curses.stdscr

# Set up initial variables
y_pos = 0
lines_added = 0

# Function to add a line to the window
def add_line(window, y_position, text)
  window.setpos(y_position, 0)
  window.addstr(text)
end

begin
  loop do
    # Add a line with current timestamp
    add_line(win, y_pos, "Line #{lines_added + 1}: #{Time.now}")

    # Increment line position and count
    y_pos += 1
    lines_added += 1

    # Refresh the screen
    win.refresh

    # Wait for 5 seconds
    sleep(1)
  end
ensure
  # Ensure to close curses properly
  Curses.close_screen
end

