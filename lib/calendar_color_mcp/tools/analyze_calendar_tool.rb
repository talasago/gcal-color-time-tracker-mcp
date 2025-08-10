require 'mcp'
require_relative 'base_tool'
require_relative '../google_calendar_client'
require_relative '../time_analyzer'
require_relative '../color_filter_manager'
require_relative '../errors'

module CalendarColorMCP
  class AnalyzeCalendarTool < BaseTool
    description "指定期間のGoogleカレンダーイベントを色別に時間集計します"

    input_schema(
      type: "object",
      properties: {
        start_date: {
          type: "string",
          description: "開始日（YYYY-MM-DD形式）"
        },
        end_date: {
          type: "string",
          description: "終了日（YYYY-MM-DD形式）"
        },
        include_colors: {
          type: "array",
          description: "集計対象の色（色ID(1-11)またはカラー名を指定）",
          items: {
            oneOf: [
              { type: "integer", minimum: 1, maximum: 11 },
              { type: "string", enum: ["薄紫", "緑", "紫", "赤", "黄", "オレンジ", "水色", "灰色", "青", "濃い緑", "濃い赤"] }
            ]
          }
        },
        exclude_colors: {
          type: "array",
          description: "集計除外の色（色ID(1-11)またはカラー名を指定）",
          items: {
            oneOf: [
              { type: "integer", minimum: 1, maximum: 11 },
              { type: "string", enum: ["薄紫", "緑", "紫", "赤", "黄", "オレンジ", "水色", "灰色", "青", "濃い緑", "濃い赤"] }
            ]
          }
        }
      },
      required: ["start_date", "end_date"]
    )

    class << self
      def call(start_date:, end_date:, include_colors: nil, exclude_colors: nil, **context)
        begin
          auth_manager = extract_auth_manager(context)
        rescue ArgumentError => e
          return error_response(e.message).build
        end

        start_date = Date.parse(start_date)
        end_date = Date.parse(end_date)

        unless auth_manager.authenticated?
          auth_url = auth_manager.get_auth_url
          return error_response("認証が必要です").with(:auth_url, auth_url).build
        end

        begin
          client = GoogleCalendarClient.new
          events = client.get_events(start_date, end_date)

          color_filter = ColorFilterManager.new(
            include_colors: include_colors,
            exclude_colors: exclude_colors
          )

          analyzer = TimeAnalyzer.new
          result = analyzer.analyze(events, start_date, end_date, color_filter: color_filter)

          success_response({
            period: {
              start_date: start_date.to_s,
              end_date: end_date.to_s,
              days: (end_date - start_date).to_i + 1
            },
            color_filter: color_filter.get_filtering_summary,
            analysis: result[:color_breakdown],
            summary: result[:summary],
            formatted_output: format_analysis_output(result, color_filter)
          })
        rescue AuthenticationError => e
          auth_url = auth_manager.get_auth_url
          return error_response(e.message).with(:auth_url, auth_url).build
        rescue CalendarApiError => e
          return error_response(e.message).build
        rescue => e
          error_response("予期しないエラーが発生しました: #{e.message}").build
        end
      end

      private

      def format_analysis_output(result, color_filter = nil)
        output = ["📊 色別時間集計結果:", "=" * 50, ""]

        # 色フィルタリング情報の表示
        if color_filter&.get_filtering_summary[:has_filters]
          filter_summary = color_filter.get_filtering_summary
          output << "🎨 色フィルタリング設定:"
          output << "  含める色: #{filter_summary[:include_colors] || '全色'}"
          output << "  除外する色: #{filter_summary[:exclude_colors] || 'なし'}"
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
