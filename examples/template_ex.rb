#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'example'

class TemplateExample < Example
  def self.parse_opts(opts, param)
    opts.banner = 'Usage: template_ex.rb [options]'

    param.x_value = Slithernix::Cdk::CENTER
    param.y_value = Slithernix::Cdk::CENTER
    param.box = true
    param.shadow = false
    super
  end

  # This program demonstrates the Cdk label widget.
  def self.main
    title = '<C>Title'
    label = '</5>Phone Number:<!5>'
    overlay = '</B/6>(___)<!6> </5>___-____'
    plate = '(###) ###-####'

    params = parse(ARGV)

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.initCDKColor

    # Declare the template.
    phone_number = Slithernix::Cdk::Widget::Template.new(
      cdkscreen,
      params.x_value,
      params.y_value,
      title,
      label,
      plate,
      overlay,
      params.box,
      params.shadow,
    )

    if phone_number.nil?
      # Exit CDK.
      cdkscreen.destroy
      Slithernix::Cdk::Screen.endCDK

      puts 'Cannot create template. Is the window too small?'
      exit # EXIT_FAILURE
    end

    # Activate the template.
    info = phone_number.activate([])

    # Tell them what they typed.
    if phone_number.exit_type == :ESCAPE_HIT
      mesg = [
        '<C>You hit escape. No information typed in.',
        '',
        '<C>Press any key to continue.'
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif phone_number.exit_type == :NORMAL
      # Mix the plate and the number.
      mixed = phone_number.mix

      # Create the message to display.
      # FIXME magic numbers
      mesg = [
        format('Phone Number with out plate mixing  : %.*s', 206, info),
        format('Phone Number with the plate mixed in: %.*s', 206, mixed),
        '',
        '<C>Press any key to continue.'
      ]
      cdkscreen.popupLabel(mesg, 4)
    end

    # Clean up
    phone_number.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    # ExitProgram (EXIT_SUCCESS);
  end
end

TemplateExample.main
