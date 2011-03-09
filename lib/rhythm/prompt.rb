# -*- coding: utf-8 -*-
module Rhythm
  class Prompt < Object
    def initialize core
      win = core.main_win
      @core = core
      @line = win.subhline(win.getmaxx, 0, 0)
      @block = lambda {|core| core }
      @cmds = {}
      @str = nil
    end

    def print str
      @str = str.to_s
      @line.clear
      @line.mvaddstr(0, @str)
      @line.noutrefresh
    end

    def << *arg
      print(*arg)
      return self
    end

    def hook arg
      name = arg[:name].to_sym
      list = @cmds[name]
      if list == nil
        list = @cmds[name] = []
      end
      list << arg
    end

    def call name
      list = @cmds[name.to_sym]
      if list
        @cmds[name.to_sym].each do |hash|
          hash.execute.call(@core, self)
        end
      end
    end

    def resize
      @line.resize(getmaxx, 0, 0)
      @line.clear
      @line.mvaddstr(0, @str)
      @line.noutrefresh
    end
    include Rhythm::GUI
  end
end

