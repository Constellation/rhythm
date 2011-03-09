# vim: fileencoding=utf-8

module Rhythm
  class FileList < Object
    attr_reader :path, :entries, :size, :sort_mode, :mask_mode, :mask, :selectable_size

    @@sort_procs = {
      :name  => lambda do |a, b|
        a.name <=> b.name
      end,
      :extension   => lambda do |a, b|
        result = a.extname <=> b.extname
        if result == 0
          result = @@sort_procs[:name].call(a, b)
        end
        result
      end,
      :size  => lambda do |a, b|
        result = a.size <=> b.size
        if result == 0
          result = @@sort_procs[:name].call(a, b)
        end
        result
      end,
      :mtime  => lambda do |a, b|
        result = a.mtime <=> b.mtime
        if result == 0
          result = @@sort_procs[:name].call(a, b)
        end
        result
      end,
    }

    def self.register_sort_mode name, &block
      @@sort_procs[name] = block
    end

    def self.register_mask name, hash
      @@masks[name] = hash
    end

    def self.sort_procs
      return @@sort_procs
    end

    def self.masks
      return @@masks
    end

    @@masks = {
      :all => {
        :type => :reg,
        :mask => '*',
        :text => 'All',
        :reg  => /.+$/,
      }
    }

    def initialize aspect
      @entries = []
      @all = []
      @table = {}
      @aspect = aspect

      if @aspect == :left
        @sort_mode = Config['LEFT_SORT_MODE']
        @sort_order = Config['LEFT_SORT_ORDER']
        @mask_mode = Config['LEFT_MASK_MODE']
        path = Config['LEFT_START_PATH'] || Dir.pwd
      else
        @sort_mode = Config['RIGHT_SORT_MODE']
        @sort_order = Config['RIGHT_SORT_ORDER']
        @mask_mode = Config['RIGHT_MASK_MODE']
        path = Config['RIGHT_START_PATH'] || Dir.pwd
      end

      @sort_files_proc = @@sort_procs[@sort_mode]
      if @sort_mode == :mtime
        @sort_dirs_proc = @@sort_procs[:mtime]
      else
        @sort_dirs_proc = @@sort_procs[:name]
      end
      @mask = @@masks[@mask_mode]

      # general sort proc
      # <DIR> on top and files sort
      @sort_proc = lambda do |a, b|
        t_a = a.top
        t_b = b.top
        if t_a
          result = -1
        elsif t_b
          result = 1
        else
          dir_a = a.dir?
          dir_b = b.dir?
          if dir_a && dir_b
            result = @sort_dirs_proc.call(a, b)
            result = 0 - result unless @sort_order
          elsif dir_a && !dir_b
            result = -1
          elsif !dir_a && dir_b
            result = 1
          elsif !dir_a && !dir_b
            result = @sort_files_proc.call(a, b)
            result = 0 - result unless @sort_order
          end
        end
        result
      end

      # FS
      # filelistはこれとentriesのwrapper
      @fs = STDFS::System.get(self, path)
      @stdfs = @fs
      refresh
    end

    def extract entry
      fs_down(ARCFS::System.get(self, entry, @fs))
    end

    def fs_up
      @fs = @fs.parent
      @fs.child = nil
    end

    def fs_down fs
      @fs.child = fs
      @fs = @fs.child
    end

    def create_entry arg
      @fs.create_entry arg
    end

    def get_entry_by_path path
      return @table[File.basename(path)]
    end

    def current
      @fs.current
    end

    def current= current
      @fs.current = current
    end

    def cd entry
#      if entry.fstype == @fs.fstype
      @fs.cd entry
      refresh
#      end
#        new_path = Pathname.new(path)
#        if new_path.absolute?
#          @fs.current = new_path
#        else
#          @fs.current = Pathname.new(File.expand_path(path, current))
#        end
#      end
#      while !current.exist? || !current.directory?
#        current = current.parent
#      end
      #refresh
    end

    # stdfsおよびftpしか認めない.
    def jump entry
      @fs.respond_to?(:finalize) && @fs.finalize
      @fs = @stdfs
      @fs.cd entry
      refresh
    end

    def selected_size
      count = 0
      @entries.each do |e|
        e.selected && count += 1
      end
      count
    end

    def refresh
      @path = @fs.current.current.to_s
      @entries.clear
      @table.clear
      @all.clear
      @fs.refresh do |entry|
        @all << entry
        masking entry
      end
      @size = @entries.size
      @selectable_size = selectable_size_count
      resort
    end

    def change_sort_mode name, order=true
      @sort_mode = name
      @sort_files_proc = @@sort_procs[name]
      if name == :mtime
        @sort_dirs_proc = @@sort_procs[name]
      else
        @sort_dirs_proc = @@sort_procs[:name]
      end
      @sort_order = order
      resort
    end

    def change_mask_mode name
      @mask_mode = name
      @mask = @@masks[name]
      remask
    end

    # normal + migemo search
    def search_entry index, n, str
      return nil if @size == 1
      if Config['MIGEMO']
        # migemo check
        migemo = Search
        unless migemo.valid
          Config["MIGEMO"] = false
          search_entry index, n, str
        else
          str = migemo.search(str)
        end
      else
        str = Regexp.escape(str)
      end
      if Config['SEARCH_FORWARD']
        reg = /^#{str}/i
      else
        reg = Regexp.compile(str, 'i')
      end
      unless Config['WRAP_SCAN']
        if n == 1
          return nil if index == @size-1
          @entries[index+1..@size-1].detect do |entry|
            reg =~ entry.name
          end
        else
          return nil if index == 0
          @entries[0..index-1].reverse.detect do |entry|
            reg =~ entry.name
          end
        end
      else
        if n == 1
          (@entries[index+1..@size-1] + @entries[0..index-1]).detect do |entry|
            reg =~ entry.name
          end
        else
          (@entries[0..index-1].reverse! + @entries[index+1..@size-1].reverse!).detect do |entry|
            reg =~ entry.name
          end
        end
      end
    end

    private
    # @entriesに受け渡し
    def remask
      @entries.clear
      @table.clear
      @all.each do |entry|
        masking entry
      end
      @size = @entries.size
      @selectable_size = selectable_size_count
      resort
    end

    def selectable_size_count
      @entries.select{|e| e.selectable?}.size
    end

    def resort
      @entries.sort!(&@sort_proc).each_with_index do |entry, index|
        entry.reindex index
      end
      self
    end

    def method_missing name, *args, &block
      @entries.send name, *args, &block if @entries.respond_to? name
    end

    def masking entry
      if entry.dir?
        @table[entry.name] = entry
        @entries << entry
      else
        if @mask[:type] == :reg
          if @mask[:reg] =~ entry.name
            @table[entry.name] = entry
            @entries << entry
          end
        elsif @mask[:type] == :lambda
          if @mask[:lambda].call(entry)
            @table[entry.name] = entry
            @entries << entry
          end
        end
      end
    end
  end
end
