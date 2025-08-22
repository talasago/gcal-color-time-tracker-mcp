# frozen_string_literal: true

module Domain
  class ColorConstants
    COLOR_NAMES = {
      1 => '薄紫', 2 => '緑', 3 => '紫', 4 => '赤', 5 => '黄',
      6 => 'オレンジ', 7 => '水色', 8 => '灰色', 9 => '青',
      10 => '濃い緑', 11 => '濃い赤'
    }.freeze

    NAME_TO_ID = COLOR_NAMES.invert.freeze
    DEFAULT_COLOR_ID = 9

    private_constant :COLOR_NAMES, :NAME_TO_ID, :DEFAULT_COLOR_ID

    def self.color_names
      COLOR_NAMES
    end

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

    def self.normalize_colors(colors)
      return [] unless colors

      colors.filter_map do |color|
        case color
        when Integer
          valid_color_id?(color) ? color.to_s : nil
        when String
          NAME_TO_ID[color]&.to_s
        else
          nil
        end
      end
    end
  end
end
