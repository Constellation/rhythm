
# -*- coding: utf-8 -*-
require "kconv"

class UnRAR < Object
  @@name = 'libunrar'
  @@rar_hdr = [
    [0x52, 0x61, 0x72, 0x21, 0x1a, 0x07, 0x00],
# unrarのsrc上のおそらくtestファイル用header
#    [?U, ?n, ?i, ?q, ?u, ?E, ?!]
  ]
  @@hosts =[
    'MS_DOS',
    'OS/2',
    'Win32',
    'UNIX',
    'Mac OS',
    'BeOS',
    'WinCE',
  ]
  @@sizes = {
    :head => 7,
    :main => 13,
    :file => 32,
    :short_block => 7,
    :long_block => 11,
    :sub_block => 14,
    :comment => 13,
    :protected => 26,
    :av => 14,
    :sign => 15,
    :uo => 18,
    :mach => 22,
    :ea => 24,
    :beea => 24,
    :stream => 26
  }
  @@main_mask = {
    :volume => 0x0001,
    :comment => 0x0002,
    :encrypted => 0x0004,
    :solid => 0x0008,
    :pack_comment => 0x0010,
    :newnumbering => 0x0010,
    :av => 0x0020,
    :protected => 0x0040,
    :password => 0x0080,
    :firstvolume => 0x0100,
    :encrypt_ver => 0x0200,
  }
  @@file_mask = {
    :split_before => 0x0001,
    :split_after => 0x0002,
    :encrypted => 0x0004,
    :commented => 0x0008,
    :solid => 0x0010,
    :unicode_name => 1 << 9,
    :salt => 1 << 10,
    :old_ver => 1 << 11,
    :exttime => 1 << 12,
  }
  def initialize path
    @arc_path = path
  end
  def self.check path
    flag = false
    File.open(path, 'rb') do |file|
      begin
        buf = file.read(7)
        c = buf.unpack('C*')
        flag = (c == @@rar_hdr[0])? true : false
#               (c == @@rar_hdr[1])? true : false
      rescue
      end
    end
    return flag
  end

  def name
    @@name
  end

  def self.name
    @@name
  end

  def construct root, sys
    tree_lists = []
    entry_list = nil
    begin
      File.open(@arc_path.to_s, 'rb') do |fd|
        entry_list = archive(fd)
      end
    rescue => e
      return false
    end

    tests = []
    entry_list.each do |st|
      e = sys.create_entry(st)
      begin
      t, names = sys.split_names(e.pathname)
      e.p = File.dirname(e.pathname)
      e.psize = names.size
      if tree_lists[e.psize] == nil
        tree_lists[e.psize] = []
      end
      tree_lists[e.psize] << e
      rescue
      end
    end

    phase = true
    temp = nil
    tree_lists.each_with_index do |list, index|
      unless list == nil
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

  def extract entry, pathname, temp_dir
    # unrar 依存
    system("unrar x -inul #{@arc_path.to_s} #{entry.pathname} #{temp_dir}")
  end

  private

  def archive fd
    fd.seek(7, IO::SEEK_CUR)
    list = []
    buf = fd.read(13)
    if !(mhd = main_header(buf, fd)).nil?
      if buf.size > mhd[:head_size]
        comment = fd.read(13, buf.head_size).encode
      end
      loop do
        offset = fd.tell
        buf = fd.read(32)
        if !(entry = file_header(buf, fd)).nil?
          fd.seek(offset + entry[:head_size] + entry[:pack_size], IO::SEEK_SET)
          list << arc_entry(entry)
        elsif !(entry = sub_header(buf, fd)).nil?
          fd.seek(offset + entry[:head_size] + entry[:name_size], IO::SEEK_SET)
        elsif !(entry = end_header(buf, fd)).nil?
          fd.seek(offset + entry[:head_size], IO::SEEK_SET)
          break
        else
          break
        end
      end
    end
    return list
  end


  # modeの存在しないRARにおいて, libarchiveのstatっぽく扱えるようwrapする
  class ArchiveEntry < Object
    attr_reader :mode, :size, :pathname, :mtime, :symlink, :hardlink
    # win_file_attrsによって, win attributesをunix modeに変更する.
    @@win_file_attrs = {
      :readonly      => 1,
      :hidden        => 2,
      :system        => 4,
      :directory     => 16,
      :archive       => 32,
      :encrypted     => 64,
      :normal        => 128,
      :temporary     => 256,
      :sparse_file   => 512,
      :reparse_point => 1024,
      :compressed    => 2048,
      :offline       => 4096,
    }
    def initialize entry
      @size = entry[:file_size]
      @pathname = entry[:filename]
      case entry[:os_type]
      when 0..2, 4, 6
        @mode = convert2unixmode(entry[:file_attr])
        @dir = !(entry[:file_attr] & @@win_file_attrs[:directory]).zero?
      when 3, 5
        @mode = entry[:file_attr]
        @dir = (@mode & 0xf000) == 0x4000
      else
        @mode = entry[:file_attr]
        @dir = (@mode & 0xf000) == 0x4000
      end

      @mtime = entry[:modified]
      @symlink = false
      @hardlink = false
    end

    def directory?
      @dir
    end

    private
    def convert2unixmode attr
      default = 0666 - File.umask
      # win attributesを計算し, UNIX modeに変換する
#      v = !(attr & 0x08).zero?#v
      d = !(attr & 0x10).zero?#directory
      r = !(attr & 0x01).zero?#readonly
#      h = !(attr & 0x02).zero?#hidden
#      s = !(attr & 0x04).zero?#system
#      a = !(attr & 0x20).zero?#archive
#      c = !(attr & 0x800).zero?#compressed
      # 解凍はunrarコマンドに任せるので, 基本それにあわせてattrを作る
      default = 0444 if r
      default |= 00040000 if d
      return default
    end
  end

  def arc_entry entry
    ArchiveEntry.new(entry)
  end

  def write

  end

  # convert dostime to unixtime
  def dostime2unixtime dostime
    sec = (dostime << 1) & 0x3e
    min = (dostime & 0x000007e0 ) >> 5
    hour = (dostime & 0x0000f800) >> 11
    day = (dostime & 0x001f0000) >> 16
    mon = (((dostime & 0x01e00000) >> 21))
    year = ((dostime & 0xfe000000) >> 25) + 1980
    return Time.gm(year, mon, day, hour, min, sec)
  end
  def main_header buf, fd
    header = {
      :head_crc => 0,
      :head_type => 0,
      :flags => 0,
      :head_size => 0,
      :highposav => 0,
      :posav => 0
    }
    # header checker
    return nil unless buf[2] == ?s
    begin
       header[:head_crc] = buf[0] + (buf[1] << 8)
       header[:head_type] = buf[2]
       header[:flags] = buf[3] + (buf[4] << 8)
       header[:head_size] = buf[5] + (buf[6] << 8)
       header[:highposav] = buf[7] + (buf[8] << 8)
       header[:posav] = buf[9] + (buf[10] << 8) + (buf[11] << 16) + (buf[12] << 24)

  #    header[:head_crc], header[:head_type], header[:flags], header[:head_size], header[:highposav], header[:posav] = buf.unpack('SCSSSL')
  #    v = header[:flags]
  #    header[:flags] = ((v >> 8) | (v & 0xFF) << 8)
      header[:solid] = !(header[:flags] & @@main_mask[:solid]).zero?
      #unless (header[:flags] & @@main_mask[:encrypt_ver]).zero?
      #  header[:encrypt_ver] = fd.read(1)
      #end
      header[:encrypted] = !(header[:flags] & @@main_mask[:encrypted] ).zero?
    rescue
      return nil
    end
    return nil if header[:head_size] < 13
    return header
  end
  def file_header t, fd
    entry = {
      :head_crc => 0,
      :head_type => 0,
      :flags => 0,
      :head_size => 0,
      :pack_size => 0,
      :file_size => 0,
      :os_type => 0,
      :file_crc => 0,
      :modified => 0,
      :unpack_ver => 0,
      :method => 0,
      :name_size => 0,
      :file_attr => 0,
      :encrypted => false,
      :solid => false,
      :commented => false,
      :has_salt => false,
      :has_exttime => false,
      :filename => "",
      :comment => "",
      :salt => "",
      :os => nil,
  #    :percent => 0,
      :high_pack => false,
      :high_pack_size => 0,
      :high_file_size => 0
    }
    # header checker
    return nil unless t[2] == ?t
    begin
      entry[:head_crc] = t[0] + (t[1] << 8)
      entry[:head_type] = t[2]
      entry[:flags] = t[3] + (t[4] << 8)
      entry[:head_size] = t[5] + (t[6] << 8)
    #  entry[:head_size] = head_size + 7 + 13 + 32# 7 => magic, 13 => main_header, 32 => itself
      entry[:pack_size] = t[7] + (t[8] << 8) + (t[9] << 16) + (t[10] << 24)
      entry[:file_size] = t[11] + (t[12] << 8) + (t[13] << 16) + (t[14] << 24)
      entry[:os_type] = t[15]
      entry[:file_crc] = (t[16] + (t[17] << 8) + (t[18] << 16) + (t[19] << 24)).to_s(16)
      entry[:modified] = dostime2unixtime(t[20] + (t[21] << 8) + (t[22] << 16) + (t[23] << 24))
      entry[:unpack_ver] = t[24]
      entry[:method] = t[25]
      entry[:name_size] = t[26] + (t[27] << 8)
      entry[:file_attr] = t[28] + (t[29] << 8) + (t[30] << 16) + (t[31] << 24)
      entry[:encrypted] = !(entry[:flags] & @@file_mask[:encrypted]).zero?
      entry[:solid] = !(entry[:flags] & @@file_mask[:solid]).zero?
      entry[:commented] = !(entry[:flags] & @@file_mask[:commented]).zero?
      entry[:has_salt] = !(entry[:flags] & @@file_mask[:salt]).zero?
      entry[:has_exttime] = !(entry[:flags] & @@file_mask[:exttime]).zero?
      entry[:os] = @@hosts[entry[:os_type]] || "unkown os"
  #    entry[:percent] = (entry[:pack_size].to_f / entry[:file_size] * 100).to_i
      unless (entry[:flags] & 0x100).zero?
        entry[:high_pack] = true
        t = fd.read(8)
        entry[:high_pack_size] = t[0] + (t[1] << 8) + (t[2] << 16) + (t[3] << 24)
        entry[:high_file_size] = t[4] + (t[5] << 8) + (t[6] << 16) + (t[7] << 24)
      end
      entry[:filename] = fd.read(entry[:name_size]).unpack('Z*').first.encode.gsub(/\\/, '/')
      if entry[:has_salt]
        entry[:salt] = fd.read(8)
      end
    rescue
      return nil
    end
    return entry
  end

  def sub_header buf, fd
    # header checker
    return nil unless buf[2] == ?z
    entry = {
      :head_size => 0,
      :name_size => 0,
      :comment => ""
    }
    begin
      entry[:head_size] = buf[5] + (buf[6] << 8)
      entry[:name_size] = buf[7] + (buf[8] << 8) + (buf[9] << 16) + (buf[10] << 24)
    rescue
      return nil
    end
    return entry
  end

  def end_header buf, fd
    # header checker
    return nil unless buf[2] == ?{
    entry = {
      :head_size => 0
    }
    begin
      entry[:head_size] = buf[5] + (buf[6] << 8)
    rescue
      return nil
    end
    return entry
  end

  class RARBlock < Object
    def initialize buf
      @checksum = buf[0] + (buf[1] << 8)
      @type = buf[2]
      @flags = buf[3] + (buf[4] << 8)
      @h_size = buf[5] + (buf[6] << 8)
      @size = 0
      unless (@flags & 0x8000).zero?
        @size = buf[7] + (buf[8] << 8) + (buf[9] << 16) + (buf[10] << 24)
      end
    end
  end
end

Rhythm::ARCFS.register UnRAR
