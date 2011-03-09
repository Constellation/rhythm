# -*- coding: utf-8 -*-
# Overlay Class

module Rhythm
  class Overlay < Object
    include Utils, GUI
    def initialize
      @overlay = Delimiter::Overlay.new(10, 50, 10, 10)
      @box, @window = @overlay.subwin2(10, 50, 0, 0)
      @box.border('|', '|', '-', '-', '+', '+', '+', '+')
      @title_color = DirColors.instance.get "OVERLAY_TITLE"
      @current_index = 0
      @stack = nil
      @opend = false
    end

    def menu opt
      Core.main_win.save
      list, @current_index, title = opt[:list] || [], opt[:current_index] || 0, opt[:title]
      maxy, maxx = getsize
      listsize = list.size
      height = listsize + 2
      x = (maxx - 40) >> 1
      y = (maxy - 10) >> 1
      open(height, 40, y, x)
      show_menu list, @current_index
      @window.noutrefresh
      @box.border('|', '|', '-', '-', '+', '+', '+', '+')
      change_title title if title
      @box.noutrefresh(true, true, true, true)
      @overlay.noutrefresh
      @overlay.doupdate

      @resize_stack = {
        :h => height,
        :w => 40,
        :type => :menu,
        :menu => list,
        :title => title
      }

      max = listsize - 1
      loop do
        type, ch = getch
        if type == :KEY
          if ch[0] == ?q
            close
            return nil
          elsif ch[0] == ?\r
            close
            return @current_index
          end
        elsif type == :FKEY
          if ch == 'up'
            if @current_index != 0
              @current_index -= 1
            end
          elsif ch == 'down'
            if @current_index != max
              @current_index += 1
            end
          end
          show_menu list, @current_index
          @window.noutrefresh
          @overlay.noutrefresh
          @overlay.doupdate
        end
      end
    end

    def message text
      maxy, maxx = getsize
      list = text.split(/\r\n|\r|\n/)
      height = list.size + 2
      x = (maxx - 40) >> 1
      y = (maxy - height) >> 1
      open(height, 40, y, x)
      list.each_with_index do |str, index|
        @window.mvaddstr(index, 0, str)
      end
      @window.noutrefresh
      @box.border('|', '|', '-', '-', '+', '+', '+', '+')
      @box.noutrefresh(true, true, true, true)
      @overlay.noutrefresh
      @overlay.doupdate
    end

    def resize
      return unless @opend
      Core.main_win.save
      height = @resize_stack[:h]
      width = @resize_stack[:w]
      type = @resize_stack[:type]
      content = @resize_stack[type]
      title = @resize_stack[:title]
      maxy, maxx = getsize
      x = (maxx - 40) >> 1
      y = (maxy - 10) >> 1
      open(height, 40, y, x)
      show_menu content, @current_index
      @window.noutrefresh

      @box.border('|', '|', '-', '-', '+', '+', '+', '+')
      change_title title if title
      @box.noutrefresh(true, true, true, true)
      @overlay.noutrefresh
      @overlay.doupdate
    end

    private
    def open height=0, width=0, y=0, x=0
      @opend = true
      @overlay.resize(height, width, y, x)
      @box.resize(height, width, 0, 0)
      @window.resize(height-2, width-2, 1, 1)
    end

    def close
      @opend = false
    end

    def change_title title
      maxx = @box.getmaxx - 1
      @box.top_hline(2, '-', maxx - 4)
      @box.draw_top(2, title.w_rmax(maxx-4, '-'), "\x1b[0;38;5;#{@title_color}m")
    end

    def getsize
      Delimiter.getsize
    end

    def show_menu list, current
      max = @window.getmaxx
      list.each_with_index do |str, index|
        if index == current
          @window.mvaddstr(index, 0, str.w_ljust(max, " "), "\x1b[7;38;5;7m")
        else
          @window.mvaddstr(index, 0, str.w_ljust(max, " "))
        end
      end
    end
  end
end

