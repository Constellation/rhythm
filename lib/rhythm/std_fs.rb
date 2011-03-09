# -*- coding: utf-8 -*-
require "pathname"
require "singleton"

module Rhythm
  module STDFS
    FSTYPE = :std
    class System < Object
      attr_accessor :current, :child
      def initialize filelist, path
        @filelist = filelist
        @parent = self
        @pane = filelist.pane
        @child = nil
        @current = create_entry(Pathname.new(File.expand_path(path)))
      end
      def create_entry(path, top=false)
        return STDFS::Entry.new(path, top)
      end
      def cd entry
        unless File.readable?(entry.path)
          raise Errno::EACCES, entry.path
        end
        @current = entry
        loop do
          if !@current.current.exist? || !@current.current.directory? || !File.readable?(@current.path)
            @current = @current.parent
          else
            break
          end
        end
      end
      def refresh
        parent = @current.parent
        unless parent.path == @current.path
          yield create_entry(parent.current).top_entry
        end
        @current.current.children.each_with_index do |path, i|
          begin
            e = create_entry(path)
          rescue => err
            next
          end
          yield e
        end
      end
      def fstype
        STDFS::FSTYPE
      end
      def fs_up
        @filelist.fs_up
      end
      def self.get filelist, path, parent=nil
        self.new filelist, path
      end
    end

    class Entry < BasicEntry
      attr_reader :path, :name, :extname, :current
      alias :real_path :path
      def initialize path, top=false
        super(top)
        @current = path
        path = path.to_s
        # printableな文字列かどうかをチェックする
        # printableでなければ例外が出て, entry作成外部で捕捉される
        path.printable?
        @stat = File.lstat(path)
        if(@stat.symlink?)
          @lpath = File.readlink(path)
          @linked_stat = File.stat(path)
        end
        @path = dir_path(@current.to_s)
        @executable = false
        @name = @top ? ".." : File.basename(path)
        @basename = File.basename(path, '.*')
        @extname = File.extname(path) || ""
        @size = @stat.size
        @dir = @stat.symlink? ? @linked_stat.directory? : @stat.directory?
        @time = @stat.mtime.strftime("%y/%m/%d %H:%M:%S")
        @mode_status = calc_mode(@stat.mode)
      end

      def top_entry
        Entry.new(@current, true)
      end

      def parent
        Entry.new(@current.parent)
      end

      def fstype
        FSTYPE
      end

      # line, statuslineは表示されるまで必要とされない(特にstatuslineは作り損な場合すら考えられる)
      # よって, 必要になったときに作成する遅延式の方が効率がよい
      # 大量のentryのあるdirectory読み込み時に顕著(ex: /usr/libなど)
      def line
        @line ||= "#{(@stat.directory? || @top)?  @name.w_ljust(20)                   :
                    (@stat.symlink?)?            "#{@name} -> #{@lpath}".w_ljust(20) :
                    "#{@basename.w_ljust(12)} #{@extname.w_rjust(6)}#{@executable ? "*" : " "}"}  #{@status.w_rjust(10)} #{@time}"
      end

      def statusline
        @statusline if @statusline
        begin
          user = @stat.uid
          user = Etc.getpwuid(user).name
        rescue
          user = user.to_s
        end
        begin
          group = @stat.gid
          group = Etc.getgrgid(group).name
        rescue
          group = group.to_s
        end
        @statusline = "#{@mode_status.rjust(6)} #{user.rjust(8)} : #{group.ljust(8)} #{@status.w_rjust(10)} #{@time} #{(@stat.symlink?)? "#{@name} -> #{@lpath}" : "#{@name}" }"
      end

      def method_missing name, *args, &block
        @stat.send(name, *args, &block)
      end

    end
  end
end

