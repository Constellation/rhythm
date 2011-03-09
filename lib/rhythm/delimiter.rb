# -*- coding: utf-8 -*-
## Delimiter
#
# Delimiter is library for cui based console application
# written by Constellation <utatane.tea@gmail.com>
# under MIT License
#

# ncurses 代替
# 256色表示可能
# 抽象化度が低層で, 少し扱いにくい代わりに好き勝手できる.
# 非常に簡易なので, 実質STDINをひとつのscreenとしたものしか受け付けません
# ambiguous 対応

require "termios"
require "highline"
require "rhythm/termstrwidth"
require "rhythm/stsize"

module Delimiter
  @ambiguous = false
  @old = nil
  @now = nil
  @@win_count = 0
  @@partial = 256
  OUT = STDOUT.clone
  ERR = STDERR.clone
  IN  = STDIN.clone
  NULL = File.open('/dev/null', 'w').to_io
#  STDERR.reopen(NULL)
  STDOUT.reopen(NULL)

  def getsize
    HighLine::SystemExtensions.terminal_size.reverse!
  end
  module_function :getsize

  def initscr
    STDIN.sync = true
    OUT.sync = true
    termios = Termios::tcgetattr(STDIN)
    @old = Marshal.load(Marshal.dump(termios))
    begin
      init_256_colors
      yield termios
    ensure
      OUT.print "\x1b[0m\n\x1b\\"
      Termios::tcsetattr(STDIN, Termios::TCSANOW, @old)
    end
  end

  def clear
    OUT.print("\033[2J")
  end

  def keypad n=true
    if n
      OUT.print "\033[?1l\033="
    else
      OUT.print "\033[?1l\033>"
    end
  end

  def move y, x
    OUT.print "\033[#{y+1};#{x+1}H\033[0m"
  end

  def cursor n=true
    if n
      #hide cursor
      str = "\033[?34l\033[?25l"
    else
      #show cursor
      str = "\033[?34h\033[?25h"
    end
    OUT.print(str)
  end

  def raw
    initscr do |newt|
      newt.lflag &= ~(Termios::ECHO | Termios::ECHONL | Termios::ICANON | Termios::ISIG | Termios::IEXTEN)
      newt.iflag &= ~(Termios::IGNBRK | Termios::BRKINT | Termios::PARMRK | Termios::ISTRIP | Termios::INLCR | Termios::IGNCR | Termios::ICRNL | Termios::IXON)
      newt.oflag &= ~Termios::OPOST
      newt.cflag &= ~(Termios::CSIZE | Termios::PARENB)
      newt.cflag |= Termios::CS8
      Termios::tcsetattr(STDIN, Termios::TCSANOW, newt)
      @now = newt
      yield newt
    end
  end

  def cbreak
#    STDIN.sync = true
#    @stdout.sync = true
#    init_256_colors
#    HighLine::SystemExtensions::raw_no_echo_mode()
#    begin
#      yield "test"
#    ensure
#      HighLine::SystemExtensions::restore_mode()
#    end
    initscr do |newt|
      newt.iflag &= Termios::IGNCR
      newt.lflag &= ~(Termios::ECHO | Termios::ECHONL | Termios::ICANON | Termios::ISIG)
      Termios::tcsetattr(STDIN, Termios::TCSANOW, newt)
      @now = newt
      yield newt
    end
  end

  def cooked
    initscr do |newt|
      yield newt
    end
  end

  def init_256_colors
    # color table definition

    # colors 16-231 are a 6x6x6 color cube
    6.times do |red|
      6.times do |green|
        6.times do |blue|
           OUT.printf("\x1b]4;%d;rgb:%x/%x/%x\x1b\\",
           16 + (red * 36) + (green * 6) + blue,
           (red ? (red * 40 + 55) : 0),
           (green ? (green * 40 + 55) : 0),
           (blue ? (blue * 40 + 55) : 0))
        end
      end
    end
    # colors 232-255 are a grayscale ramp, intentionally leaving out
    # black and white
    24.times do |gray|
      level = (gray * 10) + 8
       OUT.printf("\x1b]4;%d;rgb:%x/%x/%x\x1b\\",
       232 + gray, level, level, level)
    end
  end

  def point_map_factory(row, col)
    result = []
    row.times do |y|
      line = Array.new
      col.times do |x|
        line << Point.new(y, x, " ")
      end
      result << line
    end
    return result
  end
  module_function :point_map_factory

  def win_point_map_factory(row, col)
    return map_factory(row, col, WinPoint)
  end
  module_function :win_point_map_factory

  def overlay_point_map_factory(row, col)
    return map_factory(row, col, OverlayPoint)
  end
  module_function :overlay_point_map_factory

  def map_factory(row, col, pointclass)
    result = []
    row.times do
      line = Array.new
      col.times do
        line << pointclass.new
      end
      result << line
    end
    return result
  end
  module_function :map_factory

  def resize_win_point_map(lines, row, col)
    return resize_map(lines, row, col, WinPoint)
  end
  module_function :resize_win_point_map

  def resize_overlay_point_map(lines, row, col)
    return resize_map(lines, row, col, OverlayPoint)
  end
  module_function :resize_overlay_point_map

  def resize_map(lines, row, col, pointclass)
    maxy = lines.size
    maxx = lines[0].size
    if maxy > row
      lines = lines[0...row]
      if maxx > col
        lines = lines.map do |line|
          line = line[0...col]
          line.each{|p| p.modify }
          line
        end
      else
        lines.each do |line|
          line.each{|p| p.modify }
          (col - maxx).times do
            line << pointclass.new
          end
        end
      end
    else
      if maxx > col
        lines = lines.map do |line|
          line = line[0...col]
          line.each{|p| p.modify }
          line
        end
      else
        lines.each do |line|
          line.each{|p| p.modify }
          (col - maxx).times do
            line << pointclass.new
          end
        end
      end
      (row - maxy).times do
        line = Array.new
        col.times do
          line << pointclass.new
        end
        lines << line
      end
    end
    return lines
  end
  module_function :resize_map

  def win_point_line_factory n
    result = []
    n.times do
      result << WinPoint.new
    end
    return result
  end
  module_function :win_point_line_factory


  # きれいでないが, 速度重視
  # 縮小を先にするほうが全体と見て高速
  def resize_point_map(lines, row, col)
    maxy = lines.size
    maxx = lines[0].size
    if maxy > row
      lines = lines[0...row]
      if maxx > col
        lines = lines.map do |line|
          line[0...col]
        end
      else
        lines.each_with_index do |line, y|
          (col - maxx).times do |n|
            line << Point.new(y, maxx+n, " ")
          end
        end
      end
    else
      if maxx > col
        lines = lines.map do |line|
          line[0...col]
        end
      else
        lines.each_with_index do |line, y|
          (col - maxx).times do |n|
            line << Point.new(y, maxx+n, " ")
          end
        end
      end
      line = nil
      (row - maxy).times do |n|
        line = Array.new
        col.times do |x|
          line << Point.new(maxy+n, x, " ")
        end
        lines << line
      end
    end
    return lines
  end
  module_function :resize_point_map

  def resize_win_point_line line, n
    size = line.size
    if size > n
      line = line[0...n]
      line.each{|p| p.modify }
    else
      line.each{|p| p.modify }
      (n - size).times do
        line << WinPoint.new
      end
    end
    line
  end
  module_function :resize_win_point_line

  def clear_point_line line
    line.each do |point|
      point.renew
    end
  end
  module_function :clear_point_line

  def get_width str
    # AMBIGUOUSも考慮
    return str_size(str, Rhythm::Config['AMBIGUOUS']);
  end
  #alias get_width w_size
  module_function :get_width

  def ambiguous bool
    @ambiguous = bool
  end
  module_function :ambiguous

  def get_count
    @@win_count += 1
  end
  module_function :get_count

  def endwin
    cursor false
#    clear
  end

  def def_prog_mode screen
    screen.all_modify
    cursor false
    STDOUT.reopen(OUT)
    Termios::tcsetattr(STDIN, Termios::TCSANOW, @old)
  end

  def reset_prog_mode
    STDOUT.reopen(NULL)
    Termios::tcsetattr(STDIN, Termios::TCSANOW, @now)
    cursor true
    clear
  end

  class Key < Object
    # US Keyboardの場合もあるので, Shiftに関して区別しない
    # Ctrl, Altは確実にKeyを押しながらであることが保証できるので判別
    # ただし, UPなど一部キーについてはShiftも保証できるので判別
    attr :type
    @@keymap = {
      65 => 'up',
      66 => 'down',
      67 => 'right',
      68 => 'left',

      49 => 'home',
      50 => 'insert',
      51 => 'delete',
      52 => 'end',
      53 => 'page_up',
      54 => 'page_down',

      90 => 'shift_tab'
    }
    @@keymap4 = {
      49 => 'home',
      50 => 'insert',
      51 => 'delete',
      52 => 'end',
      53 => 'page_up',
      54 => 'page_down',
    }
    @@keymap2 = {
      65 => 'shift_up',
      66 => 'shift_down',
      67 => 'shift_right',
      68 => 'shift_left',
    }
    @@keymap_func1 = {
      49 => 'F1',
      50 => 'F2',
      51 => 'F3',
      52 => 'F4',
      53 => 'F5',
      55 => 'F6',
      56 => 'F7',
      57 => 'F8',

      80 => 'F1',
      81 => 'F2',
      82 => 'F3',
      83 => 'F4',
    }
    @@keymap_func2 = {
      48 => 'F9',
      49 => 'F10',
      51 => 'F11',
      52 => 'F12',
    }
    @@ctrl_range = Range.new(?\C-@, 0x1F)
    @@ctrl_dif = ?a - ?\C-a
    def initialize keycode, type, shift=false, alt=false, ctrl=false
      @code, @type, @shift, @alt, @ctrl = keycode, type, shift, alt, ctrl
    end
    def == key
      key.type == @type && key.code == @code
    end
    alias === ==
    def to_s
    end
    def self.create(c)
      c = c.unpack('C*')
      if !(c[0] == 27) || c.size == 1
        # 何らかの通常キーであることが確定
        # Shiftを持っての判別でなく, 結果(Sとsなど)で判別する
        if @@ctrl_range.include?(c[0])
          new((c[0] + @@ctrl_dif), :KEY, false, false, true)
        else
          new(c[0], :KEY, false, false, false)
        end
      else
        if c.size == 2
          # 何らかの通常キー+Altであることが確定
          if @@ctrl_range.include?(c[1])
            new((c[1] + @@ctrl_dif), :KEY, false, true, true)
          else
            new(c[1], :KEY, false, true, false)
          end
        else
          # 通常キーでない
          # Shiftは判別条件に入る
          if c[1] == 91
            if c.size == 3
              return :FKEY, @@keymap[c[2]]
            elsif c.size == 4 && c[3] == 126
              # home/endに関してはshiftなどの区別無し
              # sizeが4の場合は, ctrl/alt/shiftはない, もしくは区別不可
              return @@keymap[c[2]], :FKEY, false, false, false
            elsif c.size == 5
              if c[2] == 49
                return new(@@keymap_func1[c[3]], :FKEY)
              elsif c[2] == 50
                return new(@@keymap_func2[c[3]], :FKEY)
              end
            elsif c.size == 6
              if c[2] == 49
                # 矢印
                # ctrl, shiftの区別
                # 50 => S
                # 51 => A
                # 53 => C
                if c[4] == 50
                  return new(@@keymap2[c[5]], :FKEY, true, false, false)
                elsif c[4] == 51
                  return new(@@keymap2[c[5]], :FKEY, false, true, false)
                elsif c[4] == 53
                  return new(@@keymap2[c[5]], :FKEY, false, false, true)
                end
                return :FKEY, @@keymap2[c[5]]
              elsif c[5] == 126
                # pageup/pagedown/deleteの複数キー版
                # home/end/insertは受付なかった
                # shiftはうけつけず, alt/ctrlの両方押しを区別
                # shift 0
                # alt   1
                # ctrl  3
                if c[4] == 51
                  return new(@@keymap2[c[2]], :FKEY, false, true, false)
                elsif c[4] == 53
                  return new(@@keymap2[c[2]], :FKEY, false, false, true)
                elsif c[4] == 55
                  return new(@@keymap2[c[2]], :FKEY, false, true, true)
                end
              end
            elsif c.size == 7
              if c[2] == 49
                if c[5] == 50
                  return new(@@keymap2[c[2]], :FKEY, true, false, false)
                elsif c[5] == 51
                  return new(@@keymap2[c[2]], :FKEY, false, true, false)
                elsif c[5] == 53
                  return new(@@keymap2[c[2]], :FKEY, false, false, true)
                elsif c[5] == 55
                  return new(@@keymap2[c[2]], :FKEY, false, true, true)
                end
                return new(@@keymap_func1[c[3]], :FKEY)
              elsif c[2] == 50
                return new(@@keymap_func2[c[3]], :FKEY)
              end
            end
          elsif c[1] == 79
            if c.size == 3 || c.size == 4
              return :FKEY, @@keymap_func1[c[2]]
            end
          end
        end
        return :FKEY, 'others'
      end
    end
  end

  @@keymap = {
    65 => 'up',
    66 => 'down',
    67 => 'right',
    68 => 'left',

    49 => 'home',
    50 => 'insert',
    51 => 'delete',
    52 => 'end',
    53 => 'page_up',
    54 => 'page_down',

    90 => 'shift_tab'
  }
  @@keymap2 = {
    65 => 'shift_up',
    66 => 'shift_down',
    67 => 'shift_right',
    68 => 'shift_left',
  }
  @@keymap_func1 = {
    49 => 'F1',
    50 => 'F2',
    51 => 'F3',
    52 => 'F4',
    53 => 'F5',
    55 => 'F6',
    56 => 'F7',
    57 => 'F8',
    80 => 'F1',
    81 => 'F2',
    82 => 'F3',
    83 => 'F4',
  }
  @@keymap_func2 = {
    48 => 'F9',
    49 => 'F10',
    51 => 'F11',
    52 => 'F12',
  }

  def getch
    # readpartialを使用
    # その時にstockされているkeyをすべて読み込むことで
    # key repeatを適切に処理
    c = STDIN.readpartial(@@partial)
    c = c.unpack('C*')
    #Rhythm::Core::notify << c.join(',')
    if !(c[0] == 27) || c.size == 1
      return :KEY, c
    else
      if c.size == 2
        return :KEY, c[1].chr
      else
        if c[1] == 91
          if c.size == 3 || c.size == 4
            return :FKEY, @@keymap[c[2]]
          elsif c.size == 5
            if c[2] == 49
              return :FKEY, @@keymap_func1[c[3]]
            elsif c[2] == 50
              return :FKEY, @@keymap_func2[c[3]]
            end
          elsif c.size == 6
            # 矢印
            # ctrl, shiftの区別
            # 50 => S
            # 51 => A
            # 53 => C
#            if c[4] == 50
#              Key.new(@@keymap2[c[5], :FKEY, true)
#            else c[4] == 51
#              Key.new(@@keymap2[c[5], :FKEY, false, true)
#            else c[4] == 53
#              Key.new(@@keymap2[c[5], :FKEY, false, false, true)
#            end
            return :FKEY, @@keymap2[c[5]]
          end
        elsif c[1] == 79
          if c.size == 3 || c.size == 4
            return :FKEY, @@keymap_func1[c[2]]
          end
        end
      end
      return :FKEY, 'others'
    end
  end

  class WinPoint < Object
    attr_reader :ch, :full, :left, :attr
    alias full? full
    alias left? left
    def right?
      !@left
    end

    def initialize *args
      renew(*args)
    end
    def renew ch=" ", attr=nil, full=false, left=true
      @ch, @full, @attr, @left = ch, full, ((attr.nil?)? "\x1b[0m" : attr), left
      @modified = true
      self
    end
    def self.create_from point
      return new point.ch, point.attr, point.full, point.left
    end
    def modified?
      @modified
    end
    def unmodify
      @modified = false
    end
    def modify
      @modified = true
    end
    def cp_from point
      renew point.ch, point.attr, point.full, point.left
    end
  end

  # 全角および半角文字列のpoint
  # 2次元配列を含むScreenで管理
  class Point < WinPoint
    def initialize y, x, *args
      @target = "\x1b[#{y+1};#{x+1}H"
      super(*args)
    end
    def self.create_from y, x, point
      return new y, x, point.ch, point.attr, point.full, point.left
    end
    def ambiguous
      @left && Delimiter::is_ambiguous(@ch)
    end
    def print
        if @modified && @left
          @modified = false
          return "#{@target}#{@attr}#{@ch}"
        else
          return ''
        end
    end
  end

  # overlay 用 point
  # print時にx, y座標を与える
  class OverlayPoint < WinPoint
    def print y, x
      if @modified && @left
        @modified = false
        target = "\x1b[#{y+1};#{x+1}H"
        return "#{target}#{@attr}#{@ch}"
      else
        return ''
      end
    end
  end

  class Screen < Object
    attr_reader :lines
    def initialize x=nil, y=nil, zindex=0
      # clearされたlines
      # すべてPointで初期化しておく
      @size = Delimiter.getsize
      if x ==nil
        @col = getmaxx
      else
        @col = x
      end
      if y ==nil
        @row = getmaxy
      else
        @row = y
      end
      @lines = Delimiter::point_map_factory(@row, @col)
      # screen重ねあわせ時の優先度
      @zindex = zindex
      @flag = false
      @all = []
      @modified = []
      @windows = {}
    end

    def register id, window
      @windows[id] = window
    end

    def unregister id
      @windows.delete(id)
    end

    def getmaxx
      return @size[1]
    end

    def getmaxy
      return @size[0]
    end

    def getsize
      Delimiter.getsize
    end

    # windowを重ね合わせて最終的に描画すべきscreenを作成する.
    # 呼び出す基本は基盤のScreen => main Screen
    # ここで, Pointのx, yを決定し続ける.
    def merge! win
      @flag = true
      x = win.x
      y = win.y
      t_x = 0
      t_y = 0
      win.each_lines do |line, index_y|
        t_y = index_y + y
        if @lines[t_y].nil?
          break
        else
          flag = false
          line.each_with_index do |point, index_x|
            t_x = index_x + x
            if point.modified?
              unless flag
                @modified << @lines[t_y]
                flag = true
              end
              point.unmodify
              scr_p = @lines[t_y][t_x]
              if scr_p.nil?
                scr_p = Point.create_from(t_y, t_x, point)
              else
                scr_p.cp_from(point)
              end
            end
          end
        end
      end
    end

    # 高速化のために定義
    def merge_hline! hline
      @flag = true
      x = hline.x
      t_y = hline.y
      t_x = 0
      @modified << @lines[t_y]
      hline.line.each_with_index do |point, index_x|
        t_x = index_x + x
        if point.modified?
          point.unmodify
          scr_p = @lines[t_y][t_x]
          if scr_p.nil?
            scr_p = Point.create_from(t_y, t_x, point)
          else
            scr_p.cp_from(point)
          end
        end
      end
    end

    def merge_vline! vline
      @flag = true
      y = vline.y
      t_y = 0
      t_x = vline.x
      vline.line.each_with_index do |point, index_y|
        t_y = index_y + y
        if point.modified?
          @modified << @lines[t_y]
          point.unmodify
          scr_p = @lines[t_y][t_x]
          if scr_p.nil?
            scr_p = Point.create_from(t_y, t_x, point)
          else
            scr_p.cp_from(point)
          end
        end
      end
    end

    def doupdate
      if @flag
        @flag = false
        @modified.uniq!
        @modified.collect! do |line|
          line.map do |point|
            point.print
          end
        end
        OUT.print @modified.join
        @modified.clear
      end
    end

    def all_modify
      range_modify(0...@row)
    end
    alias save all_modify

    def range_modify range
      @flag = true
      @modified.push(*@lines[range])
      @lines[range].each do |line|
        line.each do |p|
          p.modify
        end
      end
    end

    # windowを作成
    def subwin row, col, y, x
      Window.new(self, row, col, y, x)
    end

    # 枠つきWindow作成
    def subwin2 row, col, y, x
      return (Border.new(self, row, col, y, x)), (Window.new(self, row-2, col-2, y+1, x+1))
    end

    # HLineを作成 => minimal
    def subhline row, y, x
      HLine.new(self, row, y, x)
    end

    # VLineを作成 => minimal
    def subvline row, y, x
      nil
    end

    # screenを作成
    def newwin row, col, y, x
      Screen.new(row, col, y, x)
    end

    def clear
      @flag = true
      @lines.each do |line|
        Delimiter::clear_point_line(line)
      end
    end

    def resize
      @size = Delimiter.getsize
      @col = @size[1]
      @row = @size[0]
      @lines = Delimiter::resize_point_map(@lines, @row, @col)
    end

    def noutrefresh
      @windows.each_value do |win|
        if win.update_flag
          win.update
        end
      end
    end
  end

  class Window < Object
    attr_reader :x, :y, :lines, :update_flag
    def initialize screen, row, col, y, x
      @x = x
      @y = y
      @row = row
      @col = col
      @id = "Win#{Delimiter::get_count}"
      screen.register(@id, self)
      @screen = screen
      @lines = Delimiter::win_point_map_factory(@row, @col)
      @flag =true
      @update_flag = false
      @scrlok = false
    end
    # 基盤screenにmergeする
    def noutrefresh
      @update_flag = true
    end
    def update
      if @flag
        @flag = false
        @screen.merge!(self)
      end
      self
    end
    def getmaxx
      @col
    end
    def getmaxy
      @row
    end
    def border lh, rh, uv, dv, lu, ru, ld, rd
      mvaddstr(0, 0, "#{lu}#{uv*(@col-2)}#{ru}")
      mvaddstr(@row-1, 0, "#{ld}#{dv*(@col-2)}#{rd}")
      1.upto(@row-2) do |y|
        mvaddch(y, 0, lh)
        mvaddch(y, @col-1, rh)
      end
    end
    def move y, x
      OUT.print "\x1b[#{@y+y+1};#{@x+x+1}H\x1b\\\x1b[0m\x1b\\"
    end
    def scrl n
      if @scrlok
        if n > 0
          n = n.abs
          n.times do
            @lines.push(Delimiter::clear_point_line(@lines.shift))
          end
        else
          n = n.abs
          n.times do
            @lines.unshift(Delimiter::clear_point_line(@lines.pop))
          end
        end
        @lines.each do |line|
          line.each do |p|
            p.modify
          end
        end
      end
    end
    def mvaddch y, x, ch, attr=nil
      ch = ch.decode
      if y < @row && x < @col
        @flag = true
        line = @lines[y]
        start = line[x]
        if x != 0 && start.right?
          line[x-1].renew(" ")
        end
        unless line[x] == nil
          line[x].renew(ch)
          x+=1
        end
        endp = line[x]
        if endp != nil && endp.right?
          line[x].renew(" ")
        end
      end
    end
    def mvhline y, x, ch, col
      mvaddstr(y, x, ch*col)
    end
    def mvaddstr y, x, str, attr=nil
      str = str.decode
      if y < @row && x < @col
        @flag = true
        line = @lines[y]
        start = line[x]
        if x != 0 && start.right?
          line[x-1].renew(" ")
        end
        str.split(Rhythm::Config['SPLITTER']).each do |ch|
          # escape sequense check(\nのみ)
          if line[x] == nil
            break
          end
          if ch == "\n"

          elsif Delimiter::get_width(ch) == 2
            if line[x+1] == nil
              break
            else
              line[x].renew(ch, attr, true, true)
              line[x+1].renew(ch, attr, true, false)
              x += 2
            end
          else
            line[x].renew(ch, attr)
            x+=1
          end
        end
        endp = line[x]
        if endp != nil && endp.right?
          line[x].renew(" ")
        end
      else
        raise "out of range"
      end
    end
    def mvprintstr y, x, str, attr=nil
      str = str.decode
      if y < @row && x < @col
        @flag = true
        line = @lines[y]
        start = line[x]
        if x != 0 && start.right?
          line[x-1].renew(" ")
        end
        str.split(Rhythm::Config['SPLITTER']).each do |ch|
          if line[x] == nil
            break
          end
          if ch == "\n"
            temp = y + 1
            if temp == @row
              scrl(1)
              line = @lines[y]
            else
              @lines.insert(temp, Delimiter::clear_point_line(@lines.pop))
              line = @lines[temp]
            end
          elsif Delimiter::get_width(ch) == 2
            if line[x+1] == nil
              break
            else
              line[x].renew(ch, attr, true, true)
              line[x+1].renew(ch, attr, true, false)
              x += 2
            end
          else
            line[x].renew(ch, attr)
            x+=1
          end
        end
        endp = line[x]
        if endp != nil && endp.right?
          line[x].renew(" ")
        end
      else
        raise "out of range"
      end
    end
    def clear_line y
      @flag = true
      Delimiter::clear_point_line(@lines[y])
    end
    def each_lines
      @lines.each_with_index do |line, index|
        yield line, index
      end
    end
    def scrollok arg=true
      @scrlok = true
    end
    def subwin row, col, y, x
      Window.new(@screen, row, col, y, x)
    end
    def clear
      @flag = true
      @lines.each do |line|
        Delimiter::clear_point_line(line)
      end
    end
    def resize row, col, y, x
      @y = y
      @x = x
      @col = col
      @row = row
      @lines = Delimiter::resize_win_point_map(@lines, @row, @col)
    end
  end

  class Border < Object
    attr_reader :top, :bottom, :left, :right, :row, :col
    def initialize screen, row, col, y, x
      @row = row
      @col = col
      @top = HLine.new(screen, col, y, x)
      @bottom = HLine.new(screen, col, y+row-1, x)
      @left = VLine.new(screen, row-2, y+1, x)
      @right = VLine.new(screen, row-2, y+1, x+col-1)
    end
    def draw_top x, str, attr
      @top.mvaddstr(x, str, attr)
    end
    def draw_bottom x, str, attr
      @bottom.mvaddstr(x, str, attr)
    end
    def draw_left y, str, attr
      @left.mvaddstr(y, str, attr)
    end
    def draw_right y, str, attr
      @right.mvaddstr(y, str, attr)
    end
    def top_hline x, str, col
      @top.mvhline(x, str, col)
    end
    def bottom_hline x, str, col
      @bottom.mvhline(x, str, col)
    end
    def left_vline y, str, row
      @left.mvvline(y, str, row)
    end
    def right_vline y, str, row
      @right.mvvline(y, str, row)
    end
    def getmaxx
      @col
    end
    def getmaxy
      @row
    end
    def border lh, rh, uv, dv, lu, ru, ld, rd
      @top.mvaddstr(0, "#{lu}#{uv*(@col-2)}#{ru}")
      @bottom.mvaddstr(0, "#{ld}#{dv*(@col-2)}#{rd}")
      @left.mvaddstr(0, lh*(@row-2))
      @right.mvaddstr(0, rh*(@row-2))
    end
    def noutrefresh t, b, l, r
      @top.noutrefresh if t
      @bottom.noutrefresh if b
      @left.noutrefresh if l
      @right.noutrefresh if r
    end
    def resize row, col, y, x
      @row = row
      @col = col
      @top.resize(col, y, x)
      @bottom.resize(col, y+row-1, x)
      @left.resize(row-2, y+1, x)
      @right.resize(row-2, y+1, x+col-1)
    end
  end

  # 1 lineを保障する => 高速, minimal
  class HLine < Object
    attr_reader :x, :y, :line, :update_flag
    def initialize screen, col, y, x
      @x = x
      @y = y
      @col = col
      @id = "Win#{Delimiter::get_count}"
      screen.register(@id, self)
      @line = Delimiter::win_point_line_factory(@col)
      @flag =true
      @update_flag = false
      @screen = screen
    end

    def noutrefresh
      @update_flag = true
    end

    def all_modify
      @flag = true
      @line.each(&:modify)
    end

    def update
      if @flag
        @flag = false
        @screen.merge_hline!(self)
      end
      self
    end

    def mvaddstr x, str, attr=nil
      if x < @col
        @flag = true
        start = @line[x]
        if x != 0 && start.right?
          @line[x-1].renew(" ")
        end
        str.split(Rhythm::Config['SPLITTER']).each do |ch|
          # escape sequense check(\nのみ)
          if @line[x] == nil
            break
          end
          if ch == "\n"

          elsif Delimiter::get_width(ch) == 2
            if @line[x+1] == nil
              break
            else
              @line[x].renew(ch, attr, true, true)
              @line[x+1].renew(ch, attr, true, false)
              x += 2
            end
          else
            @line[x].renew(ch, attr)
            x+=1
          end
        end
        endp = @line[x]
        if endp != nil && endp.right?
          @line[x].renew(" ")
        end
      else
        raise "out of range"
      end
    end

    def move y, x
      OUT.print "\x1b[#{@y+y+1};#{@x+x+1}H\x1b\\\x1b[0m\x1b\\"
    end

    def mvhline x, ch, col
      mvaddstr(x, ch*col)
    end

    def getmaxx
      @col
    end
    def getmaxy
      1
    end
    def clear
      @flag = true
      Delimiter::clear_point_line(@line)
    end

    def resize col, y, x
      @x = x
      @y = y
      @col = col
      @line = Delimiter::resize_win_point_line(@line, @col)
    end
  end

  class VLine < Object
    attr_reader :x, :y, :line, :update_flag
    def initialize screen, row, y, x
      @x = x
      @y = y
      @row = row
      @id = "Win#{Delimiter::get_count}"
      screen.register(@id, self)
      @line = Delimiter::win_point_line_factory(@row)
      @flag =true
      @update_flag = false
      @screen = screen
    end

    def noutrefresh
      @update_flag = true
    end

    def all_modify
      @flag = true
      @line.each(&:modify)
    end

    def update
      if @flag
        @flag = false
        @screen.merge_vline!(self)
      end
      self
    end

    # strは半角文字列であることを保障しなければいけない
    def mvaddstr y, str, attr=nil
      if y < @row
        @flag = true
        str.split(Rhythm::Config['SPLITTER']).each do |ch|
          # escape sequense check(\nのみ)
          if @line[y] == nil
            break
          end
          @line[y].renew(ch, attr)
          y+=1
        end
      else
        raise "out of range"
      end
    end
    def move y, x
      OUT.print "\x1b[#{@y+y+1};#{@x+x+1}H\x1b\\\x1b[0m\x1b\\"
    end
    def getmaxx
      1
    end
    def getmaxy
      @row
    end
    def clear
      @flag = true
      Delimiter::clear_point_line(@line)
    end
    def mvvline y, ch, col
      mvaddstr(y, ch*col)
    end
    def resize row, y, x
      @x = x
      @y = y
      @row = row
      @line = Delimiter::resize_win_point_line(@line, @row)
    end
  end

  class Overlay < Object
    def initialize row, col, y, x
      @x = x
      @y = y
      @row = row
      @col = col
      @lines = Delimiter::overlay_point_map_factory(@row, @col)
      @flag =true
      @update_flag = false
      @modified = []
      @windows = {}
    end

    def noutrefresh
      @windows.each_value do |win|
        if win.update_flag
          win.update
        end
      end
    end

    def getmaxx
      @col
    end

    def getmaxy
      @row
    end

    def register id, window
      @windows[id] = window
    end

    def unregister id
      @windows.delete(id)
    end

    def resize row, col, y, x
      @row = row
      @col = col
      @x = x
      @y = y
      @lines = Delimiter::resize_overlay_point_map(@lines, @row, @col)
    end

    def merge! win
      @flag = true
      x = win.x
      y = win.y
      t_x = 0
      t_y = 0
      win.each_lines do |line, index_y|
        t_y = index_y + y
        if @lines[t_y].nil?
          break
        else
          flag = false
          line.each_with_index do |point, index_x|
            t_x = index_x + x
            if point.modified?
              unless flag
                @modified << t_y
                flag = true
              end
              point.unmodify
              scr_p = @lines[t_y][t_x]
              if scr_p.nil?
                scr_p = OverlayPoint.create_from(point)
              else
                scr_p.cp_from(point)
              end
            end
          end
        end
      end
    end

    def merge_hline! hline
      @flag = true
      x = hline.x
      t_y = hline.y
      t_x = 0
      @modified << t_y
      hline.line.each_with_index do |point, index_x|
        t_x = index_x + x
        if point.modified?
          point.unmodify
          scr_p = @lines[t_y][t_x]
          if scr_p.nil?
            scr_p = OverlayPoint.create_from(point)
          else
            scr_p.cp_from(point)
          end
        end
      end
    end

    def merge_vline! vline
      @flag = true
      y = vline.y
      t_y = 0
      t_x = vline.x
      vline.line.each_with_index do |point, index_y|
        t_y = index_y + y
        if point.modified?
          @modified << t_y
          point.unmodify
          scr_p = @lines[t_y][t_x]
          if scr_p.nil?
            scr_p = OverlayPoint.create_from(point)
          else
            scr_p.cp_from(point)
          end
        end
      end
    end

    def doupdate
      if @flag
        @flag = false
        @modified.uniq!
        all = []
        @modified.each do |t_y|
          @lines[t_y].each_with_index do |point, t_x|
            all << point.print(t_y+@y, t_x+@x)
          end
        end
        OUT.print all.join
        @modified.clear
      end
    end

    def all_modify
      range_modify(0...@row)
    end
    alias save all_modify

    def range_modify range
      @flag = true
      @modified.push(*@lines[range])
      @lines[range].each do |line|
        line.each do |p|
          p.modify
        end
      end
    end

    def clear
      @flag = true
      @lines.each do |line|
        Delimiter::clear_point_line(line)
      end
    end

    def move y, x
      OUT.print "\x1b[#{@y+y+1};#{@x+x+1}H\x1b\\\x1b[0m\x1b\\"
    end

    def each_lines
      @lines.each_with_index do |line, index|
        yield line, index
      end
    end

    def subwin row, col, y, x
      Window.new(self, row, col, y, x)
    end

    def subwin2 row, col, y, x
      return (Border.new(self, row, col, y, x)), (Window.new(self, row-2, col-2, y+1, x+1))
    end

    def close
    end
  end
end

