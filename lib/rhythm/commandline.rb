require "readline"
require "rhythm/migemo_search"
# -*- coding: utf-8 -*-


module Rhythm
  class CommandLine < Object
    NEXT = 1
    PREV = -1
    include Utils, GUI
    def initialize core
      win = core.main_win
      @core = core
      @y = win.getmaxy-1
      @line = win.subhline(win.getmaxx, win.getmaxy-1, 0)
      @search_str = nil
    end

    public
    # getstr
    def getstr prompt, &block
      @line.clear
      # delimiter から抜ける
      @line.move 0, 0
      @core.def_prog_mode @core.main_win
      begin
        if block_given?
          Readline.completion_proc = block
        end
        str = Readline.readline(prompt.to_s)
      rescue Interrupt
        str = ""
      end
      # delimiter 復帰
      @core.reset_prog_mode
      updater
      return str.strip
    end

    def resize
      @line.resize(getmaxx, getmaxy-1, 0)
      @line.all_modify
      @line.noutrefresh
    end

    def ask_yes_no str
      index = choose str, ['yes', 'no']
      index.nil?  ? false : index.zero? ? true  : false
    end

    # choose method
    # choose 'delete? ', ['yes', 'no']
    # return args index
    # if you choose yes => return 0
    # else              => return 1
    # if you escape     => return nil
    def choose str, choice, default=0, shift=false
      # escape => nil
      methods = {?\e => nil}
      words = []
      current_index = default
      choice.each_with_index do |c, index|
        ch = nil
        c.size.times do |n|
          unless methods.key?(c[n])
            methods[c[n]] = index
            ch = c[n].chr
            break
          end
        end
        # c = c.sub(ch, "(#{ch})") if ch
        words << c
      end
      max = words.size - 1
      show_chose_line str, words, current_index
      updater
      type = nil
      ch = nil
      loop do
        type, ch = getch
        chr = ch[0]
        if type == :KEY
          if methods.key?(chr)
            @line.clear
            @line.noutrefresh
            return methods[chr]
          elsif chr == ?\r
            @line.clear
            @line.noutrefresh
            return current_index
          end
        end
        if chr == ?\t || ch == 'right'
          if current_index == max
            current_index = 0
          else
            current_index += 1
          end
          show_chose_line str, words, current_index
        elsif ch == 'shift_tab' || ch == 'left'
          if current_index == 0
            current_index = max
          else
            current_index -= 1
          end
          show_chose_line str, words, current_index
        end
        updater
      end
    end

    # search
    # migemo enable or disable
    def search
      if Config["ISEARCH"]
        incremental_search
      else
        str = getstr('/')
        do_search NEXT, str
      end
    end

    def next_search str=nil
      do_search NEXT, str
    end

    def prev_search str=nil
      do_search PREV, str
    end

    # progress bar
    def progress per = nil, str = nil
      @line.clear
      unless per.nil?
        x = @line.getmaxx
        size = x * per / 100
        @line.mvaddstr(0, "#{(str.nil?)? "" : str << " - "}#{per}%".w_ljust(size), "\x1b[7;38;5;7m")
      end
      @line.noutrefresh
    end

    private

    def show_chose_line str, words, index
      @line.clear
      @line.mvaddstr(0, str)
      before, current, last = words[0...index], words[index], words[index+1...words.size]
      start = str.w_size
      unless before.empty?
        before = before.join(' ') << ' '
        @line.mvaddstr(start, before)
        start += before.w_size
      end
      @line.mvaddstr(start, current, "\x1b[7;38;5;7m")
      start += current.w_size
      unless last.empty?
        last = ' ' << last.join(' ')
        @line.mvaddstr(start, last) if last
      end
      @line.noutrefresh
    end

    @@key_range = 33..126

    def incremental_search
      @line.mvaddstr(0, '/ ')
      @line.noutrefresh
      updater
      stack = []
      text = ''
      pane = get_pane
      type = nil
      ch = nil
      loop do
        type, ch = getch
        if type === :KEY
          chr = ch[0]
          if @@key_range === chr
            stack << chr.chr
            text = stack.join
            entry = pane.search NEXT, text, 0
            if entry
              show_line text
            else
              stack.pop
              text = stack.join
              show_line text
            end
          elsif chr === ?\C-h || chr === 8# Back Space
            stack.pop
            text = stack.join
            pane.search NEXT, text, 0
            show_line text
          elsif chr === ?\r || chr === ?\e# enter or escape
            @search_str = text
            @line.clear
            @line.noutrefresh
            break
          elsif chr === ?\C-n# zsh like
            pane.search NEXT, text
          elsif chr === ?\C-p# zsh like
            pane.search PREV, text
          end
        elsif ch === 'up'
          pane.search PREV, text
        elsif ch === 'down'
          pane.search NEXT, text
        end
        updater
      end
    end

    def show_line str
      @line.clear
      @line.mvaddstr(0, '/ ')
      @line.mvaddstr(2, str)
      @line.noutrefresh
    end

    def do_search n=1, str=nil
      unless str
        return unless @search_str
      else
        @search_str = str
      end
      #ここまで処理したら paneへ投げつける => move to などGUIの処理をかんがみて
      pane = get_pane
      if n === PREV
        #prev search mode
        pane.search PREV, @search_str
      else
        #next search mode
        pane.search NEXT, @search_str
      end
    end

  end
end

