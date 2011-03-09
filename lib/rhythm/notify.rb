
# -*- coding: utf-8 -*-

module Rhythm
  # IO継承 + writeをoverride
  # => syswriteを除いて適切にoutputできる
  class Notify < IO
    include GUI
    def initialize core
      @core = core
      @list = []
      @win = core.main_win
      @pane = @win.subwin(4, @win.getmaxx, @win.getmaxy-5, 0)
      @pane.scrollok true
    end

    def write str
      str = str.to_s
      @list.shift if @list.size == 3
      @list << str
      @pane.mvprintstr(@pane.getmaxy-1, 0, str)
      @pane.noutrefresh
      str.size
    end

    # quick puts
    # doupdateを自主的に
    def qputs str
      puts str
      @win.doupdate
      nil
    end

    def << *args
      puts(*args)
      return self
    end

    def resize
      @pane.resize(4, getmaxx, getmaxy-5, 0)
      @pane.clear
      @list.each do |str|
        @pane.mvprintstr(@pane.getmaxy-1, 0, str)
      end
      @pane.noutrefresh
    end

  end
end

