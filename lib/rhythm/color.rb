# -*- coding: utf-8 -*-
# Rhythm::Color library
#
# 16進color code,  (#ffffff など. #fffの表記も含む)
# rgb color code,  (rgb(255, 255, 255) など. % 表記も含む)
# named color code,(red, khakiなど. W3C準拠)
# から近似色(256色)を計算して返す
#
module Rhythm
  module Color
    private
    def _rgb_number x
      if x < 75
        return 0
      else
        q, r = (x - 55).divmod(40)
        return r < 20 ? q : q + 1
      end
    end

    def _rgb_level x
      return x.zero? ? 0 : 55 + x * 40
    end

    def _rgb_color x, y, z
      return 16 + x*36 + y*6 + z
    end

    def _grey_number x
      if x < 14
        return 0
      else
        q, r = (x - 8).divmod(10)
        return r < 5 ? q : q + 1
      end
    end

    def _grey_level x
      return x.zero? ? 0 : 8 + x * 10
    end

    def _grey_color x
      if x === 0
        return 16
      elsif x === 25
        return 231
      else
        return 231 + x
      end
    end

    @@rgb_range = 0...256

    def _convert_to_256color r, g, b
      unless @@rgb_range.include?(r) && @@rgb_range.include?(g) && @@rgb_range.include?(b)
        raise "range error"
      end
      gx = _grey_number(r)
      gy = _grey_number(g)
      gz = _grey_number(b)

      x = _rgb_number(r)
      y = _rgb_number(g)
      z = _rgb_number(b)

      if gx === gy && gy === gz
        dgr = _grey_level(gx) - r
        dgg = _grey_level(gy) - g
        dgb = _grey_level(gz) - b
        dgrey = (dgr ** 2) + (dgg ** 2) + (dgb ** 2)
        dr = _rgb_level(gx) - r
        dg = _rgb_level(gy) - g
        db = _rgb_level(gz) - b
        drgb = (dr ** 2) + (dg ** 2) + (db ** 2)
        if dgrey < drgb
          return _grey_color(gx)
        else
          return _rgb_color(x, y, z)
        end
      else
        return _rgb_color(x, y, z)
      end
    end

    # 自動判定のついたinterface
    @@method_list = [:hex_color, :rgb_color, :named_color, :hsv_color, :hsl_color]
    def get_color text, default=15
      @@method_list.each do |method|
        default = __send__(method, text) rescue next
        break
      end
      return default
    end
    module_function :get_color

    @@rgb_type = /^\s*rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)\s*$/
    @@rgb_type2 = /^\s*rgb\(\s*(\d+)%\s*,\s*(\d+)%\s*,\s*(\d+)%\s*\)\s*$/

    def rgb_color text
      if m = @@rgb_type.match(text)
        r = m[1].to_i
        g = m[2].to_i
        b = m[3].to_i
        return _convert_to_256color(r, g, b)
      elsif m = @@rgb_type2.match(text)
        r = m[1].to_i * 255 / 100
        g = m[2].to_i * 255 / 100
        b = m[3].to_i * 255 / 100
        return _convert_to_256color(r, g, b)
      else
        raise "not rgb type"
      end
    end
    module_function :rgb_color

    # method hsv_color and hsl_color
    # is inspired uuAltCSS.js
    # http://uupaa-js-spinoff.googlecode.com/svn/trunk/uuAltCSS.js/README.htm
    @@hsv_type = /^\s*hsv\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)\s*$/
    def hsv_color text
      if m = @@hsv_type.match(text)
        h = m[1].to_i
        h >= 360 && (h = 0)
        s = m[2].to_i / 100
        v = m[3].to_i / 100
        h60 = h / 60
        matrix = h60.truncate
        f = h60 - matrix
        if s.zero?
          h = (v * 255).round
          return _convert_to_256color(h, h, h)
        end
        v255 = v * 255
        p = ((1 - s) * v255).round
        q = ((1 - s * f) * v255).round
        t = ((1 - s * (1 - f)) * v255).round
        w = v255.round
        case matrix
        when 0
          return _convert_to_256color(w, t, p)
        when 1
          return _convert_to_256color(q, w, p)
        when 2
          return _convert_to_256color(p, w, t)
        when 3
          return _convert_to_256color(p, q, w)
        when 4
          return _convert_to_256color(t, p, w)
        when 5
          return _convert_to_256color(w, p, q)
        end
        return _convert_to_256color(0, 0, 0)
      else
        raise "not hsv type"
      end
    end

    @@hsl_type = /^\s*hsl\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)\s*$/
    def hsl_color text
      if m = @@hsl_type.match(text)
        # 360 equal to 0
        h = (m[1] == '360')? 0 : m[1].to_i
        s = m[2].to_i / 100
        l = m[3].to_i / 100
        if h < 120
          r = (120 - h) / 60
          g = h / 60
          b = 0
        elsif h < 240
          r = 0
          g = (240 - h) / 60
          b = (h - 120) / 60
        else
          r = (h - 240) / 60
          g = 0
          b = (360 - h) / 60
        end
        s1 = 1 - s
        s2 = s * 2
        r = s2 * (r > 1 ? 1 : r) + s1
        g = s2 * (g > 1 ? 1 : g) + s1
        b = s2 * (b > 1 ? 1 : b) + s1
        if l < 0.5
          r *= l
          g *= l
          b *= l
        else
          l1 = 1 - l
          l2 = l * 2 - 1
          r = l1 * r + l2
          g = l1 * g + l2
          b = l1 * b + l2
        end

        return _convert_to_256color(r.round, g.round, b.round)
      else
        raise "not hsl type"
      end
    end

    # W3C named color
    @@named_color_table = {
      "black"                => 16,
      "navy"                 => 18,
      "darkblue"             => 18,
      "mediumblue"           => 20,
      "blue"                 => 21,
      "darkgreen"            => 22,
      "green"                => 28,
      "teal"                 => 30,
      "darkcyan"             => 30,
      "deepskyblue"          => 39,
      "darkturquoise"        => 44,
      "mediumspringgreen"    => 48,
      "lime"                 => 46,
      "springgreen"          => 48,
      "aqua"                 => 51,
      "cyan"                 => 51,
      "midnightblue"         => 17,
      "dodgerblue"           => 33,
      "lightseagreen"        => 37,
      "forestgreen"          => 28,
      "seagreen"             => 29,
      "darkslategray"        => 23,
      "limegreen"            => 40,
      "mediumseagreen"       => 35,
      "turquoise"            => 44,
      "royalblue"            => 26,
      "steelblue"            => 31,
      "darkslateblue"        => 18,
      "mediumturquoise"      => 44,
      "indigo"               => 54,
      "darkolivegreen"       => 58,
      "cadetblue"            => 73,
      "cornflowerblue"       => 69,
      "mediumaquamarine"     => 79,
      "dimgray"              => 241,
      "slateblue"            => 62,
      "olivedrab"            => 64,
      "slategray"            => 66,
      "lightslategray"       => 102,
      "mediumslateblue"      => 99,
      "lawngreen"            => 118,
      "chartreuse"           => 118,
      "aquamarine"           => 122,
      "maroon"               => 88,
      "purple"               => 90,
      "olive"                => 100,
      "gray"                 => 243,
      "skyblue"              => 117,
      "lightskyblue"         => 117,
      "blueviolet"           => 92,
      "darkred"              => 88,
      "darkmagenta"          => 90,
      "saddlebrown"          => 88,
      "darkseagreen"         => 108,
      "lightgreen"           => 120,
      "mediumpurple"         => 98,
      "darkviolet"           => 92,
      "palegreen"            => 120,
      "darkorchid"           => 92,
      "yellowgreen"          => 112,
      "sienna"               => 130,
      "brown"                => 124,
      "darkgray"             => 247,
      "lightblue"            => 152,
      "greenyellow"          => 154,
      "paleturquoise"        => 159,
      "lightsteelblue"       => 152,
      "powderblue"           => 152,
      "firebrick"            => 124,
      "darkgoldenrod"        => 136,
      "mediumorchid"         => 134,
      "rosybrown"            => 138,
      "darkkhaki"            => 143,
      "silver"               => 249,
      "mediumvioletred"      => 162,
      "indianred"            => 167,
      "peru"                 => 172,
      "chocolate"            => 166,
      "tan"                  => 180,
      "lightgrey"            => 251,
      "palevioletred"        => 168,
      "thistle"              => 182,
      "orchid"               => 170,
      "goldenrod"            => 178,
      "crimson"              => 160,
      "gainsboro"            => 252,
      "plum"                 => 182,
      "burlywood"            => 180,
      "lightcyan"            => 195,
      "lavender"             => 189,
      "darksalmon"           => 174,
      "violet"               => 213,
      "palegoldenrod"        => 223,
      "lightcoral"           => 210,
      "khaki"                => 222,
      "aliceblue"            => 231,
      "honeydew"             => 231,
      "azure"                => 231,
      "sandybrown"           => 215,
      "wheat"                => 223,
      "beige"                => 230,
      "whitesmoke"           => 255,
      "mintcream"            => 231,
      "ghostwhite"           => 231,
      "salmon"               => 209,
      "antiquewhite"         => 230,
      "linen"                => 230,
      "lightgoldenrodyellow" => 230,
      "oldlace"              => 230,
      "red"                  => 196,
      "fuchsia"              => 201,
      "magenta"              => 201,
      "deeppink"             => 198,
      "orangered"            => 196,
      "tomato"               => 202,
      "hotpink"              => 205,
      "coral"                => 209,
      "darkorange"           => 208,
      "lightsalmon"          => 216,
      "orange"               => 214,
      "lightpink"            => 217,
      "pink"                 => 218,
      "gold"                 => 220,
      "peachpuff"            => 223,
      "navajowhite"          => 223,
      "moccasin"             => 223,
      "bisque"               => 224,
      "mistyrose"            => 224,
      "blanchedalmond"       => 230,
      "papayawhip"           => 230,
      "lavenderblush"        => 231,
      "seashell"             => 231,
      "cornsilk"             => 230,
      "lemonchiffon"         => 230,
      "floralwhite"          => 231,
      "snow"                 => 231,
      "yellow"               => 226,
      "lightyellow"          => 230,
      "ivory"                => 231,
      "white"                => 231
    }

    def named_color text
      text = text.downcase
      if @@named_color_table.key?(text)
        return @@named_color_table[text]
      else
        raise "color not found in table"
      end
    end
    module_function :named_color

    @@hex_type = /^\s*#(([\da-f])([\da-f])([\da-f])([\da-f]{3})?)\s*$/i

    def hex_color text
      if m = @@hex_type.match(text)
        n = (m[5] ? m[1] : [m[2], m[2], m[3], m[3], m[4], m[4]].join("")).to_i(16)
        r = (n >> 16) & 0xff
        g = (n >> 8 ) & 0xff
        b = n & 0xff
        return _convert_to_256color(r, g, b)
      else
        raise "not hex type"
      end
    end
    module_function :hex_color

  end
end

if __FILE__ == $0
  include Rhythm::Color
  # main
  puts get_color("#555753")
end
