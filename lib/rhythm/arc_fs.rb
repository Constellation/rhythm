# -*- coding: utf-8 -*-
require "libarchive_ruby"
require "fileutils"
require "kconv"
require "rhythm/dircolors"

module Rhythm
  module ARCFS

    if File::ALT_SEPARATOR
      SEPARATOR_PAT = /[#{Regexp.quote File::ALT_SEPARATOR}#{Regexp.quote File::SEPARATOR}]/
    else
      SEPARATOR_PAT = /#{Regexp.quote File::SEPARATOR}/
    end
    FSTYPE = :arc
    EXTRACTORS = []
    def register ext
      EXTRACTORS << ext
      return true
    end
    module_function :register


    class System < Object
      attr_reader :root, :current
      attr_accessor :child, :parent
      def initialize filelist, entry, parent_fs

        # ARCHIVE非依存
        @temp_dir = nil
        @filelist = filelist
        @top = filelist.current
        @parent = parent_fs
        @path = entry.real_path
        @child = nil
        @root = create_root_entry(entry)
        @root.parent = @top

        # ARCHIVE依存
        archive_reader(@path.to_s)
        @current = @root
      end

      def finalize
        if @temp_dir
          if File.exist?(@temp_dir)
            FileUtils.rm_rf(@temp_dir)
          end
        end
      end

      def archive_reader path
        @extractor = nil
        EXTRACTORS.detect do |ext|
          if ext.check(path)
            @extractor = ext.new(path)
            true
          else
            false
          end
        end

        unless @extractor
          return false
        end
        @extractor.construct @root, self
        Rhythm::Core::notify.puts "extracting by #{@extractor.name}"
      end

      def create_entry arc_entry, top=false
        return Entry.new(arc_entry, self, top)
      end

      def create_root_entry entry
        return Entry.root(entry, self)
      end

      def make_temp_dir
        unless @temp_dir
          @temp_dir = Rhythm::Core.create_temp_directory
        end
      end

      def cd entry
        if entry.fstype == FSTYPE && entry.fs == self
          @current = entry
        else
          fs_up
        end
      end

      def get_path path
        @root.current.join(path)
      end

      def extract entry
        make_temp_dir
        temp_path = entry.pathname
        dir = File.dirname(temp_path)
        FileUtils.mkdir_p(File.join(@temp_dir, dir))
        pathname = File.join(@temp_dir, temp_path)
        @extractor.extract(entry, pathname, @temp_dir)
        if File.exist?(pathname)
          return pathname
        else
          raise "extract error"
        end
      end

      def refresh
        parent = @current.parent
        if parent == nil
          parent = @top
        end
        yield parent.top_entry
        @current.children.each do |entry|
          yield entry
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

      # chop_basename(path) -> [pre-basename, basename] or nil
      def chop_basename(path)
        base = File.basename(path)
        if /\A#{SEPARATOR_PAT}?\z/o =~ base
          return nil
        else
          return path[0, path.rindex(base)], base
        end
      end

      # split_names(path) -> prefix, [name, ...]
      def split_names(path)
        names = []
        while r = chop_basename(path)
          path, basename = r
          names.unshift basename
        end
        return path, names
      end
      def mkdir dir, p
        unless p.include?(dir)
          p << create_dir_entry(dir)
        end
      end
    end

=begin
    class ArcEntry < BasicEntry
      attr_reader :path,
                  :basename,
                  :name,
                  :extname,
                  :statusline,
                  :mtime,
                  :size,
                  :mode,
                  :real,
                  :fs
      attr_accessor :children,
                    :parent
      @@usr = Etc.getpwuid
      @@uid = @@usr.uid
      @@gid = @@usr.gid
      def initialize fs, path, mode, size, mtime, uid=@@uid, gid=@@gid
        super(false)
        # definition
        @real = false
        @fs = fs
        @extracted_path = nil
        @arc_path = path
        @path = fs.get_path(path)
        @size = size
        @mtime = mtime# Time Class
        @mode = mode
        @children = []
        @parent = nil
        @executable = false
        @fs = system
        @filename = File.basename(@path)
        @name = @filename# show name
        @basename = File.basename(@path, '.*')
        @extname = File.extname(@pathname) || ''
        @time = @mtime.strftime("%y/%m/%d %H:%M:%S")
        @mode_status = calc_mode(@mode)
        @uid = uid
        @gid = gid

        @top = false
        make_info
      end
      public
      def read
      end
      def write
      end
      def root
        @mode_status[0] = 'd'
        @status = '<DIR>'
        @color = DirColors.instance.get "DIR"
        self
      end
      def top
        @name = ".."
        self
      end
      def make_info
        if @dir || @top
          @line_base =  @name.w_ljust(20)
        elsif symlink?
          @line_base = "#{@name} -> #{@lpath}".w_ljust(20)
        else
          @line_base = "#{@basename.w_ljust(12)} #{@extname.w_rjust(6)}#{@executable? "*" : " "}"
        end
        @line = "#{@line_base}  #{@status.w_rjust(10)} #{@time}"
        @statusline = "#{@mode_status.rjust(6)} #{Etc.getpwuid(@uid).name.rjust(8)} : #{Etc.getgrgid(@gid).name.ljust(8)} #{@status.w_rjust(10)} #{(symlink?)? "#{@name} -> #{@lpath}" : "#{@name}" }"
        self
      end
    end
=end

    class Entry < BasicEntry
      attr_reader :path, :basename, :current, :name, :extname, :symlink, :hardlink, :mtime, :size, :pathname, :mode, :real, :fs
      attr_accessor :p, :psize, :parent, :table, :children
      def initialize arc_entry, system, top=false, root=false
        super(top)
        @real = false
        @extracted_path = nil
        @root_entry = root
        @table = {}
        @children = []
        if !root || top
          @pathname = dir_path(arc_entry.pathname.toutf8)
          @current = system.get_path(@pathname)
          @path = @current.to_s
          @size = arc_entry.size
          @mtime = arc_entry.mtime
          @mode = arc_entry.mode
          @dir = arc_entry.directory?
          @symlink = arc_entry.symlink
          @hardlink = arc_entry.hardlink
          @p = nil
          @psize = 0
          @parent = nil
        else
          @pathname = dir_path(arc_entry.path.toutf8)
          @current = arc_entry.current
          @path = @current.to_s
          @size = arc_entry.size
          @mtime = arc_entry.mtime
          @mode = arc_entry.mode
          @symlink = arc_entry.symlink?
          @hardlink = false
          @dir = true
          @parent = nil
        end

        @executable = false
        @fs = system
        @name = @top ? ".." : File.basename(@pathname)
        @basename = File.basename(@pathname, '.*')
        @extname = File.extname(@pathname) || ""
        # @dir = (@slink)? @linked_stat.directory? : directory?
        @time = @mtime.strftime("%y/%m/%d %H:%M:%S")
        @mode_status = calc_mode(@mode)
        usr = Etc.getpwuid
        @uid = usr.uid
        @gid = usr.gid

        if root
          dir_c = DirColors.instance
          @mode_status[0] = 'd'
          @status = '<DIR>'
          @color = dir_c.get "DIR"
        end

      end

      def line
        @line if @line
        @line = "#{(@dir || @top)?  @name.w_ljust(20) :
                       (symlink?)? "#{@name} -> #{@lpath}".w_ljust(20) :
                                   "#{@basename.w_ljust(12)} #{@extname.w_rjust(6)}#{@executable? "*" : " "}"}  #{@status.w_rjust(10)} #{@time}"
      end

      def statusline
        @statusline if @statusline
        @statusline = "#{@mode_status.rjust(6)} #{Etc.getpwuid(@uid).name.rjust(8)} : #{Etc.getgrgid(@gid).name.ljust(8)} #{@status.w_rjust(10)} #{(symlink?)? "#{@name} -> #{@lpath}" : "#{@name}" }"
      end

      def fstype
        FSTYPE
      end

      def dir?
        @dir
      end

      def directory?
        dir?
      end

      def real_path
        unless @real
          begin
            @extracted_path = @fs.extract self
            @real = true
            return @extracted_path
          rescue
            return @extracted_path = nil
          end
        end
        return @extracted_path
      end

      def self.root entry, system, top=false
        Entry.new(entry, system, top, true)
      end

      def top_entry
        if @root_entry
          top = Entry.new(self, @fs, true, true)
        else
          top = Entry.new(self, @fs, true)
        end
        top.table = @table
        top.children = @children
        top.parent = @parent
        return top
      end

      def symlink?
        false
      end
=begin
      def children
        @table.values
      end
=end
      def []= key, val
        @table[key] = val
      end

      def [] key
        @table[key]
      end

      def has? key
        @table.key?(key)
      end
    end
  end
end

class Libarchive < Object
  @@name = "libarchive"
  def initialize arc_path
    @arc_path = arc_path
  end
  def self.check path
    begin
      Archive.read_open_filename(path) do |arc|
        entry = arc.next_header
      end
    rescue => e
      return false
    end
    return true
  end
  def name
    @@name
  end
  def self.name
    @@name
  end
  def extract entry, path, temp_dir
    Archive.read_open_filename(@arc_path.to_s) do |arc|
      while arc_entry =arc.next_header
        if entry.dir_path(arc_entry.pathname.toutf8) == entry.pathname
          unless entry.directory?
            File.open(path, 'wb') do |w|
              w << arc.read_data
            end
          end
          break
        end
      end
    end
  end
  # rootを渡すとarchiveを読み, treeを構築する
  def construct root, sys
=begin
    tree = TreeCreater.new(root)
    begin
      Archive.read_open_filename(@arc_path.to_s) do |arc|
        while entry = arc.next_header
          begin

          rescue
          end
        end
      end
    end
=end
    tree_lists = []
    begin
      Archive.read_open_filename(@arc_path.to_s) do |arc|
        while entry =arc.next_header
          begin
            e = sys.create_entry(entry)
            t, names = sys.split_names(e.pathname)
#            names.inject(root) do |p, dir|
#              mkdir(dir, p)
#            end
            e.p = File.dirname(e.pathname)
            e.psize = names.size
            unless tree_lists[e.psize]
              tree_lists[e.psize] = []
            end
            tree_lists[e.psize] << e
          rescue
          end
        end
      end
    rescue => e
      return false
    end

    phase = true
    temp = nil
    tree_lists.each_with_index do |list, index|
      if list
        if phase
          temp = list
          list.each do |entry|
            root.children << entry
            entry.parent = root
          end
          phase = false
        else
          list.each do |entry|
            temp.each do |se|
              next unless se.dir
              if se.pathname == entry.p
                se.children << entry
                entry.parent = se
                break
              end
            end
          end
          temp = list
        end
      end
    end
  end
  def create_dir_entry path
  end
  def write
  end
end

Rhythm::ARCFS.register Libarchive
