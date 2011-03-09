
$:.unshift(File.expand_path('~/dev/rhythm/lib'))
require 'uri'
require 'pp'
require 'rhythm/ftp_ex'

def test_ftp
  path = 'utatane.vs.land.to'
  Net::FTP.open(path) do |ftp|
    @ftp = ftp
    ftp.login('utatane', 'temdDOf5fWGgDJh')
    feat
    @entries = []
    list
  end
end

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
  pwd = @ftp.pwd
  @ftp.list() do |line|
    hash = parse_line_unix(line) || parse_line_win(line)
    # 内部はlist命令途中なので, mdtmは出てから.
    if hash
      hash[:file] = File.join(pwd, hash[:file])
      @entries << hash
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
  end
end

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

@@reg_long = /(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)/
@@reg_short = /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)/
def parse_line_unix line
  h = {}
  # 汚い? まあまあいいじゃないですか
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
@reg_win = /(\d+)\/(\d+)\/(\d+)\s+(\d\d):(\d\d)\s+(\S+)\s+(.+)/
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

test_ftp
