# -*- coding: utf-8 -*-
require "iconv"
require "kconv"
require "rhythm/stsize"

class String
  def decode
    return Iconv.conv('UTF-8//TRANSLIT', "#{Rhythm::Config['CHARMAP']}//IGNORE", self)
  end

  def encode n=nil
    if n
      return Iconv.conv(n, 'UTF-8', self)
    else
      return toutf8
    end
  end

  def printable?
    begin
      Delimiter::get_width(self)
    end
    return self
  end

  def w_ljust max, padding=' '
    count = 0
    tmp = []
    str = self.decode
    enc = Rhythm::Config['CHARMAP']
    str.split(splitter).each do |c|
    #split(splitter).each do |c|
      count += Delimiter::get_width(c)
      if count < max
        tmp << c.encode(enc)
      elsif count == max
        tmp << c.encode(enc)
        return tmp.join('')
      else
        tmp << padding
        return tmp.join('')
      end
    end
    tmp << (padding * (max - count))
    return tmp.join('')
  end

  def w_lmax max, padding=' '
    count = 0
    tmp = []
    str = self.decode
    enc = Rhythm::Config['CHARMAP']
    str.split(splitter).each do |c|
    #split(splitter).each do |c|
      count += Delimiter::get_width(c)
      if count < max
        tmp << c.encode(enc)
      elsif count == max
        tmp << c.encode(enc)
        return tmp.join('')
      else
        tmp << padding
        return tmp.join('')
      end
    end
    return tmp.join('')
  end

  def w_rjust max, padding=' '
    count = 0
    tmp = []
    str = self.decode
    enc = Rhythm::Config['CHARMAP']
    str.split(splitter).reverse!.each do |c|
    #split(splitter).reverse!.each do |c|
      count += Delimiter::get_width(c)
      if count < max
        tmp << c.encode(enc)
      elsif count == max
        tmp << c.encode(enc)
        return tmp.reverse!.join('')
      else
        tmp << padding
        return tmp.reverse!.join('')
      end
    end
    tmp << (padding * (max - count))
    return tmp.reverse!.join('')
  end

  def w_rmax max, padding=' '
    count = 0
    tmp = []
    str = self.decode
    enc = Rhythm::Config['CHARMAP']
    str.split(splitter).reverse!.each do |c|
    #split(splitter).reverse!.each do |c|
      count += Delimiter::get_width(c)
      if count < max
        tmp << c.encode(enc)
      elsif count == max
        tmp << c.encode(enc)
        return tmp.reverse!.join('')
      else
        tmp << padding
        return tmp.reverse!.join('')
      end
    end
    return tmp.reverse!.join('')
  end

  def w_size
    count = 0
    str = self.decode
    str.split(splitter).each do |c|
    #split(splitter).each do |c|
      count += Delimiter::get_width(c)
    end
    return count
  end

  private
  def splitter
    return Rhythm::Config['SPLITTER']
  end
end

