#!/usr/bin/env ruby
# frozen_string_literal: true

require 'curses'
require 'open3'
require 'pty'
require 'pry'
require 'pastel'

require_relative '../lib/slithernix/cdk'

class SynchronizedWindow
  def initialize(window)
    @window = window
    @mutex = Mutex.new
  end

  def method_missing(method_name, *args, &block)
    if @window.respond_to?(method_name)
      @mutex.synchronize do
        @window.send(method_name, *args, &block)
      end
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    @window.respond_to?(method_name, include_private) || super
  end
end

module Util
  class ExecutionException < StandardError; end

  ESCAPE_PREFIX = "\u0002" # Ctrl-B
  ESCAPE_SUFFIX = "\u0003" # Ctrl-C

  def self.curses_method(escape_sequence); end

  def self.valid_escape_sequence(escape_sequence); end

  def self.process_line(line)
    processed_line = String.new
    current_escape_sequence = String.new

    line.each_char.to_a.each_with_index do |ch, _i|
      in_escape_sequence = true if ch == "\e"
      in_escape_sequence = false if ch =~ /\s/

      if in_escape_sequence
        current_escape_sequence << ch
        if valid_escape_sequence(current_escape_sequence)
          processed_line << curses_method(
            current_escape_sequence
          ).call(current_escape_sequence)
          current_escape_sequence = String.new
          next
        end
      end

      processed_line << ch
    end

    processed_line
  end

  def self.load_terminal_capabilities(infocmp_output: nil)
    infocmp_output ||= `infocmp -1 -q`
    terminal_capabilities = {}

    infocmp_output.each_line do |line|
      next if line.start_with?('#') || !line.start_with?(/\s/)

      line.chomp! ",\n"
      line.strip!
      delimiter = line.include?('#') ? '#' : '='
      k, v = line.split(delimiter, 2).map(&:strip)
      terminal_capabilities[k] ||= {}
      terminal_capabilities[k][:ansi_code] = v
      terminal_capabilities[k][:ansi_code] = true if v.nil?
      terminal_capabilities[k][:regex] = ansi_to_regex(v)
      terminal_capabilities[k][:curses_method] = termcap_to_curses(
        terminal_capabilities[k]
      )
    end

    terminal_capabilities
  end

  def self.ansi_to_regex(ansi_code)
    # Escape special characters in the ANSI code
    escaped_code = Regexp.escape(ansi_code)

    # Replace parameters (digits and semicolons) with a capture group
    # \e - Escape character
    # \[ - Literal '['
    # (?: - Non-capturing group for parameters
    # \d+ - Match one or more digits (parameter values)
    # ;? - Optional semicolon separator
    # )? - End of non-capturing group (parameters are optional)
    # [a-zA-Z] - Final ANSI escape sequence letter (e.g., m for color)
    regex_pattern = '\\e\\[ (?: \\d+ ;? )* [a-zA-Z]'

    # Construct the full regex pattern by combining the escaped ANSI code and the pattern
    /#{escaped_code}(#{regex_pattern})/

    # Return the compiled regular expression
  end

  def self.termcap_to_curses(cap)
    {
      'bold' => proc { Curses.attron(Curses::A_BOLD) },
      'blink' => proc { Curses.attron(Curses::A_BLINK) },
      'clear' => proc { Curses.clear },
      'cup' => proc { |row, col| Curses.setpos(row, col) },
      'cuu1' => proc { Curses.stdscr.up },
      'cud1' => proc { Curses.stdscr.down },
      'cuf1' => proc { Curses.stdscr.right },
      'cub1' => proc { Curses.stdscr.left }
      # Add more mappings as needed
    }[cap]
  end

  def self.extract_color_code_from_escape_sequence(sequence)
    color_regex = /\e\[(\d+);(?:\d+;)?(?:\d*)m/
    match = sequence.match(color_regex)
    return nil unless match

    match[1].to_i
  end

  def self.convert_terminal_color_to_curses(color_code)
    return_color = Curses.color_pair(1)

    if color_code >= 0 && color_code <= 255
      return_color = Curses.color_pair(color_code + 1)
    end

    return_color
  end

  def self.process_terminal_output(output)
    output.dup
  end

  def self.regular_character?(_char)
    # return true if char.match?(/[ -~]/)
    # return true if "\n\r\t".include?(char)
    # false
    true
  end

  def self.is_process_alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  rescue Errno::EPERM
    true
  end

  def self.is_thread_dead_or_dying?(t)
    ['aborting', false, nil].include?(t.status)
  end

  def self.execute_command(cmd:, env: {}, log: nil, interactive: false, curses_window: nil)
    raise ExecutionException, 'You must pass cmd to this method' if cmd.nil?

    log&.debug "Executing command: #{cmd} with env #{env}"

    curses_window ||= setup_curses_window
    y_pos = 0
    x_pos = 0

    Pastel.new
    curses_window.addstr("Hit ctrl-B then ctrl-C to terminate an unresponsive process\n")
    y_pos += 1
    exit_status = 1

    original_stty = `stty -g`.chomp

    curses_window.setpos(y_pos, x_pos)
    begin
      PTY.spawn(env, cmd) do |stdout, stdin, pid|
        # system "stty raw -echo"

        reader = Thread.new do
          loop do
            break if stdout.closed?
            break unless is_process_alive?(pid)

            # Char by Char (incompatible with unicode)
            # out_ch = stdout.read_nonblock(1)
            # if regular_character? out_ch
            #  curses_window.addch out_ch
            #  x_pos += 1 unless out_ch == "\n"
            #  y_pos += 1 if out_ch == "\n"
            # end

            # Whole String
            # output = process_output_with_color(stdout.read_nonblock(1024))
            # output = process_terminal_output(stdout.read_nonblock(1024))
            stdout.read_nonblock(1024).each_line do |line|
              line = process_line(line)
              next if line.empty?

              curses_window.addstr(line)
              x_pos += line.size
              y_pos += 1
            end
            # output.each_char do |c|
            #  if regular_character? c
            #    curses_window.addch c
            #    x_pos += 1 if (c != "\n" and c != "
")
            #    y_pos += 1 if (c == "\n" or c == "
")
            #  end
            # end

            curses_window.setpos(y_pos, x_pos)
            curses_window.refresh
          rescue IO::WaitReadable
            retry
          rescue EOFError, Errno::EIO
            break
          end
        end

        writer = Thread.new do
          buffer = String.new
          begin
            loop do
              break if stdout.closed?
              break unless is_process_alive?(pid)
              break if is_thread_dead_or_dying?(reader)

              # char = $stdin.read_nonblock(1)
              char = curses_window.get_char
              if buffer.empty? && char == ESCAPE_PREFIX
                buffer << char
              elsif buffer == ESCAPE_PREFIX && char == ESCAPE_SUFFIX
                Process.kill(9, pid) if is_process_alive?(pid)
                break
              else
                buffer.clear
                stdin.write(char) unless stdin.closed?
              end
            end
          rescue IO::WaitReadable
            retry
          rescue EOFError, Errno::EIO
            break
          end
        end

        reader.join
        writer.join
        begin
          _, status = Process.waitpid2(pid)
          exit_status = status.exitstatus
        rescue Errno::ECHILD
          log&.error "Could not get exit status of spawned process PID #{pid}"
          exit_status = -42
        end
      end
    rescue PTY::ChildExited
      log&.error 'The child exited unexpectedly!'
      exit_status = -43
    ensure
      system "stty #{original_stty}"
    end

    exit_status ||= -44
    exit_status
  end

  def self.setup_curses_window
    Curses.init_screen
    Curses.noecho
    Curses.cbreak
    Curses.raw
    Curses.stdscr.keypad(true)

    if Curses.has_colors?
      Curses.start_color
      limit = [Curses.colors, 256].min

      pair = 1
      (0...limit).each do |fg|
        (0...limit).each do |bg|
          Curses.init_pair(pair, fg, bg)
          pair += 1
        end
      end
    end

    @pry_window = Curses::Window.new(Curses.lines, Curses.cols, 0, 0)
    @pry_window.timeout = 0
    @pry_window.refresh
    @pry_window
  end

  def self.close_curses_window
    @pry_window&.close
    Curses.close_screen
  end
end

pry_window = Util.setup_curses_window
synchronized_pry_window = SynchronizedWindow.new(pry_window)
# Util.execute_command(cmd: 'pry --no-pager --no-color', interactive: true, curses_window: synchronized_pry_window)
Util.execute_command(cmd: 'bash', interactive: true,
                     curses_window: synchronized_pry_window)
# Util.execute_command(cmd: 'bash -l', interactive: true, curses_window: pry_window)
Util.close_curses_window
