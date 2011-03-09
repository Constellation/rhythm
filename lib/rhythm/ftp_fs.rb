# -*- coding: utf-8 -*-
$:.unshift(File.expand_path('~/dev/rhythm/lib'))
require 'uri'
require 'pp'
require 'rhythm/basic_fs'
require 'rhythm/ftp_ex'

module Rhythm
  module FTPFS
    FSTYPE = :ftp
    class System < Object
      attr_reader :entries
      # months data table
      @@months = {
        'Jan' => 1,
        'Feb' => 2,
        'Mar' => 3,
        'Apr' => 4,
        'May' => 5,
        'Jun' => 6,
        'Jul' => 7,
        'Aug' => 8,
        'Sep' => 9,
        'Oct' => 10,
        'Nov' => 11,
        'Dec' => 12
      }
      # unix ls parse regexp
      @@reg_long = /(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)/
      @@reg_short = /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)/
      # win dir parse regexp
      @reg_win = /(\d+)\/(\d+)\/(\d+)\s+(\d\d):(\d\d)\s+(\S+)\s+(.+)/

      def initialize filelist, entry, parent_fs
        @temp_dir = nil
        @filelist = filelist
        #@pane = filelist.pane
        @pane = entry
        @uri = URI.parse(entry.path)
        @pass = entry.pass
        @user = entry.user
        @tz_offset = nil
        @entries = []
        # 初期通信
        Net::FTP.open(@uri.host) do |ftp|
          @ftp = ftp
          @ftp.login(@user, @pass)
          @system = @ftp.system
          @pwd = @ftp.pwd
          begin
            @ftp.chdir(@uri.path)
          rescue
          end
          feat
          list
        end
      end

      def finalize
        if @temp_dir
          if File.exist?(@temp_dir)
            FileUtils.rm_rf(@temp_dir)
          end
        end
      end

      def cd entry
        if entry.fstype == FSTYPE
          Net::FTP.open(@uri.host) do |ftp|
            @ftp = ftp
            @ftp.login(@user, @pass)
            begin
            @ftp.chdir(entry.path)
            rescue
            end
            @pwd = @ftp.pwd
            list
          end
        end
        #  fs_up
      end

      def make_temp_dir
        unless @temp_dir
          @temp_dir = Rhythm::Core.create_temp_directory
        end
      end

      def refresh entries, hash
        @entries.each do |entry|
          entries << entry
          if entry.top
            hash[File.basename(entry.path)] = entry
          else
            hash[entry.name] = entry
          end
        end
      end

      def self.get filelist, entry, parent
        self.new(filelist, entry, parent)
      end

      def fstype
        FSTYPE
      end

      def fs_up
        # 終了処理
        finalize
        @filelist.fs_up
      end

      private
      def feat
        # 実行可能な拡張命令のlistを作る
        # MDTMがあれば, 適切なmtime計算ができる
        begin
          @feat_list = @ftp.feat
        rescue
          @feat_list = []
        end
      end

      def list
        @ftp.list() do |line|
          hash = parse_line_unix(line) || parse_line_win(line)
          # 内部はlist命令途中なので, mdtmは出てから.
          if hash
            if hash[:file] === '..'
              hash[:top] = true
            end
            unless hash[:file] === '.'
              hash[:file] = File.join(@pwd, hash[:file])
              @entries << hash
            end
          else
            # 大域脱出
            raise 'non compliant ftp server'
          end
        end
        unless @tz_offset
          calc_tz_offset(@entries[0])
        end
        @entries = @entries.map do |entry|
          entry[:mtime] += @tz_offset
          Entry.factory(@pane, entry)
        end
      end

      # serverの表示時間が自分のtime zoneとは限らない.
      # mdtm commandが使えれば, それを使ってepoch秒を取得し,
      # それとlistの表示からの計算誤差からmtimeを修正する.
      def calc_tz_offset entry
        if @feat_list.include?("MDTM")
          begin
            time = Time.at(@ftp.mdtm(entry[:file]))
            @tz_offset = entry[:mtime] - time
          rescue
            @tz_offset = 0
          end
        else
          @tz_offset = 0
        end
      end

      # unix ls version
      def parse_line_unix line
        h = {}
        # 汚い? まあまあいいじゃないですか.
        if line =~ @@reg_long
          h[:mode], h[:nlink], h[:user], h[:group], size, month, day, year, h[:file] = $1, $2, $3, $4, $5, $6, $7, $8, $9
        elsif line =~ @@reg_short
          h[:mode], h[:user], h[:group], size, month, day, year, h[:file] = $1, $2, $3, $4, $5, $6, $7, $8
        else
          return nil
        end
        modeb = 0
        mode = h[:mode]
        # stat->mode作成
        # format bit
        if mode[0] === ?d
          modeb |= 0040000
        elsif mode[0] === ?l
          modeb |= 0120000
          # link処理 => linkとlink先の確保
          num = h[:file].index(' -> ')
          h[:file], h[:link] = h[:file][0, num], h[:file][num+4..-1]
        else
          modeb |= 0100000
        end
        1.upto(9) do |n|
          modeb |= (1 << (9 - n)) unless mode[n] == ?-
        end
        # mtime 構築
        if year =~ /(\d\d):(\d\d)/
          hour, min = $1, $2
          now = Time.now
          now_year = now.year
          now_month = now.month
          mi = @@months[month]
          # 半月計算
          if now_month + 5 < mi
            year = now_year - 1
          else
            year = now_year
          end
          mtime = Time.gm(year, month, day, hour, min)
        else
          mtime = Time.gm(year, month, day)
        end
        h[:mode] = modeb
        h[:mtime] = mtime
        h[:size] = size.to_i
        return h
      end

      # windows dir version
      def parse_line_win line
        h = {}
        if line =~ @reg_win
          year, month, day, hour, min, size, h[:file] = $1, $2, $3, $4, $5, $6, $7
        else
          return nil
        end
        h[:mtime] = Time.gm(year, month, day, hour, min)
        modeb = 0
        if size === '<DIR>'
          # case: directory
          modeb |= 0040000
        else
          # case: file
          modeb |= 0100000
          h[:size] = size.to_i
        end
        # default permission
        modeb |= (0666 - File.umask)
        h[:mode] = modeb
        return h
      end
    end

    class Entry < Rhythm::BasicEntry
      attr_reader :path, :name, :extname, :line, :statusline
      def initialize pane, hash, top
        @pane = pane
        super(top)
        @time = hash[:mtime].strftime("%y/%m/%d %H:%M:%S")
        @path = dir_path(hash[:file])
        @executable = false
        @name = @top ? '..' : File.basename(@path)
        @basename = File.basename(@path, '.*')
        @extname = File.extname(@path) || ''
        @size = hash[:size] || 0
        @mode_status = calc_mode(hash[:mode])
        @symlink = @type === :link
        @lpath = hash[:link] if @symlink
        @line_base = (@type === :dir || @top)?  @name.w_ljust(20) :
                       (@symlink)? "#{@name} -> #{@lpath}".w_ljust(20) :
                                   "#{@basename.w_ljust(12)} #{@extname.w_rjust(6)}#{@executable? "*" : " "}"

        @line = "#{@line_base}  #{@status.w_rjust(10)} #{@time}"
        @line.printable?

        @statusline = "#{@mode_status.rjust(6)} #{hash[:user].rjust(8)} : #{hash[:group].ljust(8)} #{@status.w_rjust(10)} #{(@symlink)? "#{@name} -> #{@lpath}" : "#{@name}" }"
        @statusline.printable?
      end

      def top_entry
        Entry.new(@pane, @path, true)
      end

      def fstype
        FSTYPE
      end

      def real_path
        return nil
      end

      def self.factory pane, hash
        return new pane, hash, !!hash[:top]
      end
    end
  end
end

