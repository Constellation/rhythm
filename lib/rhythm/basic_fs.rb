# -*- coding: utf-8 -*-
require 'etc'
require 'rhythm/dircolors'
require 'rhythm/termstrwidth'

module Rhythm
  # 全 Entry の抽象 Class
  class BasicEntry < Object
    attr_reader :index, :selected, :top, :dir, :color, :color
    alias :selected? :selected
    alias :dir? :dir
    alias :top? :top
    def initialize top
      @selected = false
      @top = top
      @dir = false
    end

    def reindex count
      @index = count
      self
    end

    def select
      @selected = true unless @top
    end

    def unselect
      @selected = false
    end

    def toggle_select
      @selected = !@selected unless @top
      @selected
    end

    def selectable?
      (@top)? nil : true
    end

    def calc_mode pbit
      # permission bit 計算 + 表示
      dir_c = DirColors.instance
      mode = Array.new(10, '-')
      mt = pbit & 0170000
      @backcolor = dir_c.get "BACK"
      # S_IFMT
      case mt
      # S_IFDIR
      when 00040000
        mode[0] = 'd'
        @status = '<DIR>'
        @type = :dir
        @color = dir_c.get "DIR"
      # S_IFBLK
      when 0060000
        mode[0] = 'b'
        @status = '<BLK>'
        @type = :blk
        @color = dir_c.get "BLK"
      # S_IFCHR
      when 0020000
        mode[0] = 'c'
        @status = '<CHR>'
        @type = :chr
        @color = dir_c.get "CHR"
      # S_IFLNK
      when 0120000
        mode[0] = 'l'
        @status = '<LNK>'
        if @dir
          @type = :ldir
          @color = dir_c.get "DIR"
        else
          @type = :lnk
          @color = dir_c.get "LINK"
        end
      # S_IFFIFO
      when 0010000
        mode[0] = 'p'
        @status = '<PIPE>'
        @type = :pipe
        @color = dir_c.get "FIFO"
      # S_IFSOCK
      when 0140000
        mode[0] = 's'
        @status = '<SOCK>'
        @type = :sock
        @color = dir_c.get "SOCK"
      else
        @color = dir_c.get @extname
        if Config['HUMAN_READABLE']
          @status = humanize_number(@size)
        elsif Config['SIZE_CURRENCY']
          @status = to_currency(@size)
        else
          @status = @size.to_s
        end
      end
      u = pbit & 00700
      g = pbit & 00070
      o = pbit & 00007
      mode[1] = 'r' unless (u & 0400).zero?
      mode[2] = 'w' unless (u & 0200).zero?
      unless (u & 0100).zero?
        mode[3] = 'x'
        @executable = true
      end
      mode[4] = 'r' unless (g & 0040).zero?
      mode[5] = 'w' unless (g & 0020).zero?
      mode[6] = 'x' unless (g & 0010).zero?
      mode[7] = 'r' unless (o & 0004).zero?
      mode[8] = 'w' unless (o & 0002).zero?
      mode[9] = 'x' unless (o & 0001).zero?
      mode.join('')
    end

    # directory path 正規化
    # 特定の形に固定する. => 最終文字は/でない (File.dirnameの返すものにあわせる)
    def dir_path path
      path.chomp!('/') unless path == '/'
      return path
    end

    private
    @@bytes = ['', 'K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y']
    def humanize_number size
      cnt = 0
      loop do
        break if size <= 1023 && cnt < 8
        size /= 1024.0
        cnt += 1
      end
      if 0 < size && size <= 9
        sprintf("%.1f%s", ((size*10.0).ceil)/10.0, @@bytes[cnt])
      else
        sprintf("%i%s", size.ceil, @@bytes[cnt])
      end
    end

    def to_currency size
      # http://www.ruby-lang.org/ja/man/html/_C0B5B5ACC9BDB8BD.html#a.a5.b5.a5.f3.a5.d7.a5.eb
      return size.to_s.gsub(/(\d)(?=(?:\d\d\d)+(?!\d))/, '\1,')
    end
  end
end

