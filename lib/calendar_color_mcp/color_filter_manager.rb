module CalendarColorMCP
  class ColorFilterManager
    # TimeAnalyzerと同じ色定義を使用
    COLOR_NAMES = {
      1 => '薄紫', 2 => '緑', 3 => '紫', 4 => '赤', 5 => '黄',
      6 => 'オレンジ', 7 => '水色', 8 => '灰色', 9 => '青',
      10 => '濃い緑', 11 => '濃い赤'
    }.freeze

    # カラー名からIDへの逆引きマップ
    NAME_TO_ID = COLOR_NAMES.invert.freeze

    def initialize(include_colors: nil, exclude_colors: nil)
      @include_color_ids = normalize_colors(include_colors)
      @exclude_color_ids = normalize_colors(exclude_colors)
      
      validate_colors(@include_color_ids, 'include_colors') if @include_color_ids
      validate_colors(@exclude_color_ids, 'exclude_colors') if @exclude_color_ids
    end

    def should_include_color?(color_id)
      color_id = color_id&.to_i || 9  # デフォルトは青

      # excludeが指定されていて、その中に含まれる場合は除外
      if @exclude_color_ids && @exclude_color_ids.include?(color_id)
        return false
      end

      # includeが指定されていて、その中に含まれない場合は除外
      if @include_color_ids && !@include_color_ids.include?(color_id)
        return false
      end

      # その他の場合は含める
      true
    end

    def filter_events(events)
      filtered_events = events.select do |event|
        color_id = event.color_id&.to_i || 9
        should_include_color?(color_id)
      end

      if ENV['DEBUG']
        STDERR.puts "\n=== 色フィルタリング結果 ==="
        STDERR.puts "フィルタリング設定:"
        STDERR.puts "  含める色: #{format_color_list(@include_color_ids)}" if @include_color_ids
        STDERR.puts "  除外する色: #{format_color_list(@exclude_color_ids)}" if @exclude_color_ids
        STDERR.puts "全イベント数: #{events.length}"
        STDERR.puts "フィルタリング後: #{filtered_events.length}"
        STDERR.puts "除外イベント数: #{events.length - filtered_events.length}"
        
        # 除外されたイベントの詳細
        excluded_events = events - filtered_events
        if excluded_events.any?
          STDERR.puts "\n除外されたイベント："
          excluded_events.each do |event|
            color_id = event.color_id&.to_i || 9
            color_name = COLOR_NAMES[color_id] || "不明"
            STDERR.puts "  - #{event.summary} (色: #{color_name})"
          end
        end
        STDERR.puts "=" * 30
      end

      filtered_events
    end

    def get_filtering_summary
      {
        include_colors: @include_color_ids ? format_color_list(@include_color_ids) : nil,
        exclude_colors: @exclude_color_ids ? format_color_list(@exclude_color_ids) : nil,
        has_filters: @include_color_ids || @exclude_color_ids
      }
    end

    private

    def normalize_colors(colors)
      return nil if colors.nil? || colors.empty?

      Array(colors).map do |color|
        case color
        when Integer
          color
        when String
          # カラー名からIDに変換
          NAME_TO_ID[color] || raise(ArgumentError, "無効なカラー名: '#{color}'")
        else
          raise ArgumentError, "色は整数IDまたはカラー名文字列で指定してください: #{color}"
        end
      end.uniq
    end

    def validate_colors(color_ids, parameter_name)
      return unless color_ids

      invalid_ids = color_ids.reject { |id| COLOR_NAMES.key?(id) }
      if invalid_ids.any?
        raise ArgumentError, "#{parameter_name}に無効な色ID: #{invalid_ids.join(', ')}。有効なIDは1-11です。"
      end
    end

    def format_color_list(color_ids)
      return nil unless color_ids

      color_ids.map { |id| "#{COLOR_NAMES[id]}(#{id})" }.join(', ')
    end
  end
end