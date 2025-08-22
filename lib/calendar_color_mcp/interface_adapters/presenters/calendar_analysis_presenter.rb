module InterfaceAdapters
  module Presenters
    class CalendarAnalysisPresenter
      def self.format_text(result, include_colors: nil, exclude_colors: nil)
        output = ["📊 色別時間集計結果:", "=" * 50, ""]

        if include_colors || exclude_colors
          output << "🎨 色フィルタリング設定:"
          output << "  含める色: #{include_colors&.join(', ') || '全色'}"
          output << "  除外する色: #{exclude_colors&.join(', ') || 'なし'}"
          output << ""
        end

        result[:color_breakdown].each do |color_name, data|
          hours = data[:total_hours]
          minutes = ((hours % 1) * 60).round

          output << "🎨 #{color_name}:"
          output << "  時間: #{hours.to_i}時間#{minutes}分"
          output << "  イベント数: #{data[:event_count]}件"

          if data[:events].any?
            main_events = data[:events].first(3).map { |e| e[:title] }.join(", ")
            output << "  主なイベント: #{main_events}"
          end
          output << ""
        end

        summary = result[:summary]
        output << "📈 サマリー:"
        output << "  総時間: #{summary[:total_hours]}時間"
        output << "  総イベント数: #{summary[:total_events]}件"

        if summary[:most_used_color]
          most_used = summary[:most_used_color]
          output << "  最も使用された色: #{most_used[:name]} (#{most_used[:hours]}時間、#{most_used[:percentage]}%)"
        end

        output.join("\n")
      end
    end
  end
end