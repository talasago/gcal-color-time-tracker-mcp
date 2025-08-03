require 'mcp'
require_relative '../google_calendar_client'
require_relative '../time_analyzer'
require_relative '../user_manager'
require_relative '../auth_manager'

module CalendarColorMCP
  class AnalyzeCalendarTool < MCP::Tool
    description "指定期間のGoogleカレンダーイベントを色別に時間集計します"
    
    input_schema(
      type: "object",
      properties: {
        user_id: {
          type: "string",
          description: "ユーザーID（認証に使用）"
        },
        start_date: {
          type: "string",
          description: "開始日（YYYY-MM-DD形式）"
        },
        end_date: {
          type: "string",
          description: "終了日（YYYY-MM-DD形式）"
        }
      },
      required: ["user_id", "start_date", "end_date"]
    )

    def self.call(user_id:, start_date:, end_date:, server_context: {})
      user_manager = server_context[:user_manager]
      auth_manager = server_context[:auth_manager]
      
      start_date = Date.parse(start_date)
      end_date = Date.parse(end_date)

      # 認証確認
      unless user_manager.authenticated?(user_id)
        auth_url = auth_manager.get_auth_url(user_id)
        return MCP::Tool::Response.new([{
          type: "text",
          text: {
            success: false,
            error: "認証が必要です",
            auth_url: auth_url
          }.to_json
        }])
      end

      # 分析実行
      begin
        client = GoogleCalendarClient.new(user_id)
        events = client.get_events(start_date, end_date)

        analyzer = TimeAnalyzer.new
        result = analyzer.analyze(events, start_date, end_date)

        response_data = {
          success: true,
          user_id: user_id,
          period: {
            start_date: start_date.to_s,
            end_date: end_date.to_s,
            days: (end_date - start_date).to_i + 1
          },
          analysis: result[:color_breakdown],
          summary: result[:summary],
          formatted_output: format_analysis_output(user_id, result)
        }

        MCP::Tool::Response.new([{
          type: "text",
          text: response_data.to_json
        }])
      rescue Google::Apis::AuthorizationError
        auth_url = auth_manager.get_auth_url(user_id)
        MCP::Tool::Response.new([{
          type: "text",
          text: {
            success: false,
            error: "認証の更新が必要です",
            auth_url: auth_url
          }.to_json
        }])
      rescue => e
        MCP::Tool::Response.new([{
          type: "text",
          text: {
            success: false,
            error: e.message
          }.to_json
        }])
      end
    end

    private

    def self.format_analysis_output(user_id, result)
      output = ["📊 #{user_id} の色別時間集計結果:", "=" * 50, ""]

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