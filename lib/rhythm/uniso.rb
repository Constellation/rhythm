@@iso_hdr = [0x43, 0x44, 0x30, 0x30, 0x31, 0x01, 0x00]
@@sector_size = 2048
@@vd_size = 883
def check buf
  c = buf.unpack('CCCCCCC')
  return c == @@iso_hdr
end

def calc_mode pbit
  # permission bit 計算 + 表示
  mode = Array.new(10, '-')
  mt = pbit & 0170000
  # S_IFMT
  case mt
  # S_IFDIR
  when 00040000
    mode[0] = 'd'
    @status = '<DIR>'
  # S_IFBLK
  when 0060000
    mode[0] = 'b'
    @status = '<BLK>'
    @type = :blk
  # S_IFCHR
  when 0020000
    mode[0] = 'c'
    @status = '<CHR>'
    @type = :chr
  # S_IFLNK
  when 0120000
    mode[0] = 'l'
    @status = '<LNK>'
    if @dir
      @type = :ldir
    else
      @type = :lnk
    end
  # S_IFFIFO
  when 0010000
    mode[0] = 'p'
    @status = '<PIPE>'
    @type = :pipe
  # S_IFSOCK
  when 0140000
    mode[0] = 's'
    @status = '<SOCK>'
    @type = :sock
  else
    @status = @size.to_s
  end
  u = pbit & 00700
  g = pbit & 00070
  o = pbit & 00007
  mode[1] = 'r' if u & 00400 != 0
  mode[2] = 'w' if u & 00200 != 0
  if u & 00100 != 0
    mode[3] = 'x'
    @executable = true
  end
  mode[4] = 'r' if g & 00040 != 0
  mode[5] = 'w' if g & 00020 != 0
  mode[6] = 'x' if g & 00010 != 0
  mode[7] = 'r' if o & 00004 != 0
  mode[8] = 'w' if o & 00002 != 0
  mode[9] = 'x' if o & 00001 != 0
  mode.join('')
end
