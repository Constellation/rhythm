# -*- coding: utf-8 -*-
# id3 tagを読み取り, IMG以外のtext情報をhashに格納して返す.
require 'kconv'
require 'pp'
$KCODE = 'u'

module Rhythm
  module ID3
    module_function
    def has_id3_tag fd
      temp = fd.read(128)# id3 v1 固定長
      begin
        resolve_id3v1(temp)
      rescue NotID3V1Tag
        header = check_id3v2(temp)
        fd.seek(10, IO::SEEK_SET)
        temp = fd.read(header[:size])
        resolve_id3v2(temp, header)
      rescue NotID3V2Tag
        puts 'error'
      end
    end

    @@id3_v1_id = [?T, ?A, ?G]
    class NotID3V1Tag < Exception
    end
    def resolve_id3v1 data
      # version 1
      header = data[0,3].unpack('C*')
      if header === @@id3_v1_id
        if data[4] === ?+
          # true => v1 false => v1.1
          version = true
        else
          version = false
        end
      else
        raise NotID3V1Tag
      end
    end

    @@id3_v2_id = [?I, ?D, ?3]
    class NotID3V2Tag < Exception
    end
    def check_id3v2 data
      h = {
        :size => 0,
        :ver  => 0,
        :unsync => false,
        :ext => false,
        :comp => false,
      }
      header = data[0, 3].unpack('C*')
      if header === @@id3_v2_id
        h[:ver] = data[3]
        revision_number = data[4]
        flag = data[5]
        h[:unsync] = !(flag & 0x80).zero?
        h[:ext] = !(flag & 0x40).zero?
        h[:comp] = !(flag & 0x20).zero?
        # 先頭1bitは必ず0
        # また, 無視されるので, 1byteの最大単位は128 => 7shift
        h[:size] = data[9] + (data[8] << 7) + (data[7] << 14) + (data[6] << 21)
        puts "ID3 v2.#{h[:ver]}", flag, h[:size]
        return h
      else
        raise NotID3V2Tag
      end
    end

    def resolve_id3v2 data, header
      flames = []
      offset = 0
      case header[:ver]
      when 4, 3
        if header[:ext]
          header[:ext], offset = get_ext_v4(data, offset)
        end
        flame, offset = get_flame_v4(data, offset)
        pp flame
        flame, offset = get_flame_v4(data, offset)
        pp flame
        flame, offset = get_flame_v4(data, offset)
        pp flame
        flame, offset = get_flame_v4(data, offset)
        pp flame
        flame, offset = get_flame_v4(data, offset)
        pp flame
        flame, offset = get_flame_v4(data, offset)
        pp flame
        flame, offset = get_flame_v4(data, offset)
        pp flame
      when 3
        if header[:ext]
          header[:ext], offset = get_ext_v3(data, offset)
        end
        flame, offset = get_flame_v3(data, offset)
        p flame
      when 2
        flame, offset = get_flame_v2(data, offset)
        p flame
      when 1
        flame, offset = get_flame_v1(data, offset)
        p flame
      when 0
        flame, offset = get_flame_v0(data, offset)
        p flame
      end
    end
    def get_flame_v4 data, offset
      h = {
        :id => 0,
        :data  => 0,
      }
      flame = data[offset, 10]
      h[:id] = flame[0, 4]
      if h[:id][0] === ?T
        h[:type] = :text
      end
      h[:size] = flame[7] + (flame[6] << 8) + (flame[5] << 16) + (flame[4] << 24)
      h[:tap] = !(flame[8] & 0x80).zero?
      h[:fap] = !(flame[8] & 0x40).zero?
      h[:readonly] = !(flame[8] & 0x20).zero?
      h[:compression] = !(flame[9] & 0x80).zero?
      h[:encryption] = !(flame[9] & 0x40).zero?
      h[:grouping] = !(flame[9] & 0x20).zero?
      if h[:type] === :text
        h[:encoding] = data[offset+=10, 1]
        h[:data] = data[offset+=1, h[:size]-1].toutf8
        offset += h[:size] - 1
      else
        h[:data] = data[offset+=10, h[:size]].toutf8
        offset += h[:size]
      end
      return h, offset
    end

    def get_flame_v0 data, offset
      h = {
        :id => 0,
        :data  => 0,
      }
      flame = data[offset, 6]
      h[:table] = flame[0, 3]
      size = flame[5] + (flame[4] << 7) + (flame[3] << 14)
      #h[:data] = data[offset+=6, size]
      return h, offset+size
    end
  end
end

File.open(File.expand_path('~/being.mp3')) do |file|
  Rhythm::ID3.has_id3_tag(file)
end
