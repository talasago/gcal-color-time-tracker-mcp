require 'mcp'
require_relative 'google_calendar_client'
require_relative 'time_analyzer'
require_relative 'user_manager'
require_relative 'auth_manager'

module CalendarColorMCP
  class Server < MCP::Server
    def initialize
      super(
        name: "calendar-color-analytics",
        version: "1.0.0"
      )

      @user_manager = UserManager.new
      @auth_manager = AuthManager.new

      setup_tools
      setup_resources
    end

    private

    def setup_tools
      # カレンダー分析ツール
      tool "analyze_calendar" do
        description "指定期間のGoogleカレンダーイベントを色別に時間集計します"
        argument :user_id, String, required: true, description: "ユーザーID（認証に使用）"
        argument :start_date, String, required: true, description: "開始日（YYYY-MM-DD形式）"
        argument :end_date, String, required: true, description: "終了日（YYYY-MM-DD形式）"
        call do |args|
          handle_analyze_calendar(args)
        end
      end

      # 認証開始ツール
      tool "start_auth" do
        description "Google Calendar認証を開始します"
        argument :user_id, String, required: true, description: "ユーザーID"
        call do |args|
          handle_start_auth(args)
        end
      end

      # 認証状態確認ツール
      tool "check_auth_status" do
        description "認証状態を確認します"
        argument :user_id, String, required: true, description: "ユーザーID"
        call do |args|
          handle_check_auth_status(args)
        end
      end
    end

    def setup_resources
      # ユーザー認証状態リソース
      resource "auth://users" do
        name "User Authentication Status"
        description "全ユーザーの認証状態一覧"
        mime_type "application/json"
        call do
          get_users_auth_status
        end
      end

      # カレンダー色定義リソース
      resource "calendar://colors" do
        name "Calendar Colors"
        description "Googleカレンダーの色定義"
        mime_type "application/json"
        call do
          get_calendar_colors
        end
      end
    end

    # ツールハンドラー
    def handle_analyze_calendar(args)
      user_id = args[:user_id]
      start_date = Date.parse(args[:start_date])
      end_date = Date.parse(args[:end_date])

      # 認証確認
      unless @user_manager.authenticated?(user_id)
        auth_url = @auth_manager.get_auth_url(user_id)
        return {
          success: false,
          error: "認証が必要です",
          auth_url: auth_url
        }
      end

      # 分析実行
      begin
        client = GoogleCalendarClient.new(user_id)
        events = client.get_events(start_date, end_date)

        analyzer = TimeAnalyzer.new
        result = analyzer.analyze(events, start_date, end_date)

        {
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
      rescue Google::Apis::AuthorizationError
        auth_url = @auth_manager.get_auth_url(user_id)
        {
          success: false,
          error: "認証の更新が必要です",
          auth_url: auth_url
        }
      rescue => e
        {
          success: false,
          error: e.message
        }
      end
    end

    def handle_start_auth(args)
      user_id = args[:user_id]
      auth_url = @auth_manager.get_auth_url(user_id)

      {
        success: true,
        user_id: user_id,
        auth_url: auth_url,
        instructions: "上記URLにアクセスして認証を完了してください。認証後、再度分析を実行できます。"
      }
    end

    def handle_check_auth_status(args)
      user_id = args[:user_id]
      authenticated = @user_manager.authenticated?(user_id)

      result = {
        success: true,
        user_id: user_id,
        authenticated: authenticated
      }

      unless authenticated
        result[:auth_url] = @auth_manager.get_auth_url(user_id)
        result[:message] = "認証が必要です"
      else
        result[:message] = "認証済みです"
      end

      result
    end

    # リソースハンドラー
    def get_users_auth_status
      users = @user_manager.list_users
      auth_status = users.map do |user_id|
        {
          user_id: user_id,
          authenticated: @user_manager.authenticated?(user_id),
          last_auth: @user_manager.last_auth_time(user_id)
        }
      end

      {
        total_users: users.count,
        users: auth_status
      }.to_json
    end

    def get_calendar_colors
      TimeAnalyzer::COLOR_NAMES.to_json
    end

    # ヘルパーメソッド
    def format_analysis_output(user_id, result)
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
