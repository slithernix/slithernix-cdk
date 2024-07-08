#!/usr/bin/env ruby
# frozen_string_literal: true

require 'etc'
require_relative 'example'

class AlphalistExample < CLIExample
  @@my_undo_list = []
  @@my_user_list = []

  def self.getUserList(list)
    while (ent = Etc.getpwent)
      list << ent.name
    end
    Etc.endpwent
    list.sort!

    list.size
  end

  def self.fill_undo(widget, deleted, data)
    top = widget.scroll_field.getCurrentTop
    item = widget.get_current_item

    undo = OpenStruct.new
    undo.deleted = deleted
    undo.topline = top
    undo.original = -1
    undo.position = item

    @@my_undo_list << undo
    (0...@@my_user_list.size).each do |n|
      if @@my_user_list[n] == data
        @@my_undo_list[-1].original = n
        break
      end
    end
  end

  def self.parse_opts(opts, params)
    opts.banner = 'Usage: alpha_ex.rb [options]'

    # default values
    params.box = true
    params.shadow = false
    params.x_value = Slithernix::Cdk::CENTER
    params.y_value = Slithernix::Cdk::CENTER
    params.h_value = 0
    params.w_value = 0
    params.c = false

    super

    opts.on('-c', 'create the data after the widget') do
      params.c = true
    end
  end

  # This program demonstrates the Cdk alphalist widget.
  #
  # Options (in addition to normal CLI parameters):
  #   -c      create the data after the widget
  def self.main
    params = parse(ARGV)
    title = "<C></B/24>Alpha List\n<C>Title"
    label = '</B>Account: '
    user_list = []

    # Get the user list.
    user_size = AlphalistExample.getUserList(user_list)

    if user_size <= 0
      warn 'Cannot get user list'
      exit # EXIT_FAILURE
    end

    @@my_user_list = user_list.clone

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.init_color

    # Create the alphalist list.
    alpha_list = Slithernix::Cdk::Widget::AlphaList.new(
      cdkscreen,
      params.x_value,
      params.y_value,
      params.h_value,
      params.w_value,
      title,
      label,
      params.c ? nil : user_list,
      params.c ? 0 : user_size,
      '_',
      Curses::A_REVERSE,
      params.box,
      params.shadow,
    )

    if alpha_list.nil?
      cdkscreen.destroy
      Slithernix::Cdk::Screen.end_cdk

      warn 'Cannot create widget.'
      exit # EXIT_FAILURE
    end

    do_delete = lambda do |_widget_type, widget, _alpha_list, _key|
      size = []
      list = widget.get_contents(size)
      size = size[0]
      result = false

      if size.positive?
        save = widget.scroll_field.getCurrentTop
        first = widget.get_current_item

        AlphalistExample.fill_undo(widget, first, list[first])
        list = list[0...first] + list[first + 1..]
        widget.set_contents(list, size - 1)
        widget.scroll_field.setCurrentTop(save)
        widget.set_current_item(first)
        widget.draw(widget.border_size)
        result = true
      end
      result
    end

    do_delete1 = lambda do |_widget_type, widget, _alpha_list, _key|
      size = []
      list = widget.get_contents(size)
      size = size[0]
      result = false

      if size.positive?
        save = widget.scroll_field.getCurrentTop
        first = widget.get_current_item

        first -= 1
        if (first + 1).positive?
          AlphalistExample.fill_undo(widget, first, list[first])
          list = list[0...first] + list[first + 1..]
          widget.set_contents(list, size - 1)
          widget.scroll_field.setCurrentTop(save)
          widget.set_current_item(first)
          widget.draw(widget.border_size)
          result = true
        end
      end
      result
    end

    do_help = lambda do |_widget_type, _widget, _client_data, _key|
      message = [
        'Alpha List tests:',
        '',
        'F1 = help (this message)',
        'F2 = delete current item',
        'F3 = delete previous item',
        'F4 = reload all items',
        'F5 = undo deletion',
      ]
      cdkscreen.popup_label(message, message.size)
      true
    end

    do_reload = lambda do |_widget_type, widget, _alpha_list, _key|
      result = false

      if @@my_user_list.size.positive?
        widget.set_contents(@@my_user_list, @@my_user_list.size)
        widget.set_current_item(0)
        widget.draw(widget.border_size)
        result = true
      end
      result
    end

    do_undo = lambda do |_widget_type, widget, _alpha_list, _key|
      result = false
      if @@my_undo_list.size.positive?
        size = []
        oldlist = widget.get_contents(size)
        size = size[0] + 1
        deleted = @@my_undo_list[-1].deleted
        original = @@my_user_list[@@my_undo_list[-1].original]
        newlist = oldlist[0..deleted - 1] + [original] + oldlist[deleted..]
        widget.set_contents(newlist, size)
        widget.scroll_field.setCurrentTop(@@my_undo_list[-1].topline)
        widget.set_current_item(@@my_undo_list[-1].position)
        widget.draw(widget.border_size)
        @@my_undo_list = @@my_undo_list[0...-1]
        result = true
      end
      result
    end

    alpha_list.bind(:AlphaList, '?', do_help, nil)
    alpha_list.bind(:AlphaList, Slithernix::Cdk::KEY_F(1), do_help, nil)
    alpha_list.bind(:AlphaList, Slithernix::Cdk::KEY_F(2), do_delete,
                    alpha_list)
    alpha_list.bind(:AlphaList, Slithernix::Cdk::KEY_F(3), do_delete1,
                    alpha_list)
    alpha_list.bind(:AlphaList, Slithernix::Cdk::KEY_F(4), do_reload,
                    alpha_list)
    alpha_list.bind(:AlphaList, Slithernix::Cdk::KEY_F(5), do_undo, alpha_list)

    alpha_list.set_contents(user_list, user_size) if params.c

    # Let them play with the alpha list.
    word = alpha_list.activate([])

    # Determine what the user did.
    if alpha_list.exit_type == :ESCAPE_HIT
      mesg = [
        '<C>You hit escape. No word was selected.',
        '',
        '<C>Press any key to continue.'
      ]
      cdkscreen.popup_label(mesg, 3)
    elsif alpha_list.exit_type == :NORMAL
      mesg = [
        '<C>You selected the following',
        format('<C>(%.*s)', 246, word), # FIXME: magic number
        '',
        '<C>Press any key to continue.'
      ]
      cdkscreen.popup_label(mesg, 4)
    end

    # Clean up.
    alpha_list.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.end_cdk
    exit
  end
end

AlphalistExample.main
