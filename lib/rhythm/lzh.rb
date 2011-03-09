# Copyright (c) 2009 wantora
# MIT license
class Lha
  class Stat
  attr_reader :name

    def initialize(stat)
      @name = stat[:name]
    end
  end

  def self.open(path)
    ar = new(path)
    begin
      yield ar
    ensure
      ar.close
    end
  end

  attr_reader :path

  include Enumerable

  def initialize(path)
    @path = path
    @f = File.open(path, "rb")
  end

  def each
    while stat = succ
      yield stat
    end
  end

  def close
    @f.close
  end

  def closed?
    @f.closed?
  end

  def succ
    header = @f.read(21)
    return if header[0] == 0

    packed = header[7..10].unpack("V")[0]
    level = header[20]

    case level
    when 0x00 # level0
      lv0header(header)

      filename = get_filename(header)

      @f.seek(packed, IO::SEEK_CUR)
    when 0x01 # level1
      lv0header(header)
      ext = read_ext(header[-2..-1].unpack("v")[0])

      name = get_filename(header)
      filename = get_path(name.length == 0 ? ext[:file] : name, ext[:dir])

      @f.seek(packed - ext[:length], IO::SEEK_CUR)
    when 0x02 # level2
      hedsize = lv2header(header)
      ext = read_ext(header[24..25].unpack("v")[0])

      filename = get_path(ext[:file], ext[:dir])

      @f.seek(packed, IO::SEEK_CUR)
      @f.seek(1, IO::SEEK_CUR) if (hedsize - 1) == (26 + ext[:length])
    end

    Stat.new(:name => filename)
  end

  private

  EXT_TABLE = {
    0x00 => :common,
    0x01 => :file,
    0x02 => :dir,
  }

  def lv0header(header)
    hedsize = header[0]
    header << @f.read(hedsize - 21 + 2)
    hedsize
  end

  def lv2header(header)
    hedsize = header[0..1].unpack("v")[0]
    header << @f.read(24 - 21 + 2)
    hedsize
  end

  def read_ext(extsize)
    ext = {:length => 0}
    while extsize > 0
      ext[:length] += extsize

      extheader = @f.read(extsize)
      ext[EXT_TABLE[extheader[0]]] = extheader[1..-3]
      extsize = extheader[-2..-1].unpack("v")[0]
    end

    ext
  end

  def get_filename(header)
    header[22, header[21]].gsub(/\\/, "/")
  end

  def get_path(file, dir)
    if dir
      dir.gsub(/\xff/n, "/") + file
    else
      file
    end
  end
end

Lha.open(File.expand_path('~/lzhfmt.lzh')) do |arc|
  arc.each do |stat|
  puts stat.name
  end
end
