module CalendarColorMCP
  class ColorConstants
    COLOR_NAMES = {
      1 => '薄紫', 2 => '緑', 3 => '紫', 4 => '赤', 5 => '黄',
      6 => 'オレンジ', 7 => '水色', 8 => '灰色', 9 => '青',
      10 => '濃い緑', 11 => '濃い赤'
    }.freeze

    NAME_TO_ID = COLOR_NAMES.invert.freeze
    
    DEFAULT_COLOR_ID = 9

    def self.name_to_id
      NAME_TO_ID
    end

    def self.default_color_id
      DEFAULT_COLOR_ID
    end

    def self.color_names_array
      COLOR_NAMES.values
    end

    def self.valid_color_id?(id)
      COLOR_NAMES.key?(id)
    end

    def self.color_name(id)
      COLOR_NAMES[id]
    end
  end
end