
# -*- coding: utf-8 -*-

module Rhythm
  class StatusLine < Object
    include GUI
    def initialize core
      win = core.main_win
      @core = core
      @line = win.subhline(win.getmaxx, win.getmaxy-6, 0)
      @str = ''
    end

    def print str
      @str = str.to_s
      @line.clear
      @line.mvaddstr(0, @str)#"\x1b[0m")
      @line.noutrefresh
    end

    def << *args
      print *args
      return self
    end

    def resize
      @line.resize(getmaxx, getmaxy-6, 0)
      @line.clear
      @line.mvaddstr(0, @str)
      @line.noutrefresh
    end
  end
end

