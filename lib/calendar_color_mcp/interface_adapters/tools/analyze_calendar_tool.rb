require 'mcp'
require_relative 'base_tool'
require_relative '../../application/use_cases/analyze_calendar_use_case'
require_relative '../../color_constants'
require_relative '../../color_filter_manager'
require_relative '../errors'

module InterfaceAdapters
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
              { type: "string", enum: CalendarColorMCP::ColorConstants.color_names_array }
            ]
          }
        },
        exclude_colors: {
          type: "array",
          description: "集計除外の色（色ID(1-11)またはカラー名を指定）",
          items: {
            oneOf: [
              { type: "integer", minimum: 1, maximum: 11 },
              { type: "string", enum: CalendarColorMCP::ColorConstants.color_names_array }
            ]
          }
        }
      },
      required: ["start_date", "end_date"]
    )

    class << self
      def call(start_date:, end_date:, include_colors: nil, exclude_colors: nil, **context)
        logger.info "Starting calendar analysis: #{start_date} to #{end_date}"
        logger.debug "Parameters: include_colors=#{include_colors}, exclude_colors=#{exclude_colors}"

        begin
          # 1. パラメータ変換
          parsed_start_date = Date.parse(start_date)
          parsed_end_date = Date.parse(end_date)
          color_filters = build_color_filters(include_colors, exclude_colors)

          use_case = Application::AnalyzeCalendarUseCase.new(
            calendar_repository: extract_calendar_repository(context),
            filter_service: extract_filter_service(context),
            # TODO:これはここでいらないかも。ユースケース層で知ってれば良さそう。
            analyzer_service: extract_analyzer_service(context),
            token_manager: extract_token_manager(context),
            auth_manager: extract_auth_manager(context)
          )

          result = use_case.execute(
            start_date: parsed_start_date,
            end_date: parsed_end_date,
            color_filters: color_filters,
          )

          # TODO:これ必要なのだろうか？filterはuse caseの中でやるはず
          color_filter = CalendarColorMCP::ColorFilterManager.new(
            include_colors: include_colors,
            exclude_colors: exclude_colors
          )

          success_response({
            period: {
              start_date: parsed_start_date.to_s,
              end_date: parsed_end_date.to_s,
              days: (parsed_end_date - parsed_start_date).to_i + 1
            },
            color_filter: color_filter.get_filtering_summary,
            analysis: result[:color_breakdown],
            summary: result[:summary],
            formatted_output: format_analysis_output(result, color_filter)
          })

        rescue Application::AuthenticationRequiredError => e
          logger.debug "Authentication error: #{e.message}"
          auth_url = extract_auth_manager(context).get_auth_url
          error_response(e.message, auth_url: auth_url)
        rescue Application::InvalidParameterError => e
          logger.error "Validation error: #{e.message}"
          error_response("Invalid parameters: #{e.message}")
        rescue Application::CalendarAccessError => e
          logger.error "Calendar access error: #{e.message}"
          error_response("Calendar access failed: #{e.message}")
        rescue InterfaceAdapters::DependencyInjectionError => e
          logger.error "Dependency injection failed: #{e.message}"
          error_response("Server configuration error: #{e.message}")
        rescue ArgumentError => e
          logger.error "Failed to extract manager: #{e.message}"
          error_response(e.message)
        rescue => e
          logger.error "Unexpected error occurred: #{e.message}"
          logger.debug "Error details: #{e.backtrace&.first(5)&.join(', ')}"
          error_response("予期しないエラーが発生しました: #{e.message}")
        end
      end

      private

      def build_color_filters(include_colors, exclude_colors)
        return nil unless include_colors || exclude_colors

        filters = {}
        filters[:include_colors] = include_colors if include_colors
        filters[:exclude_colors] = exclude_colors if exclude_colors
        filters
      end


      def extract_calendar_repository(context)
        server_context = context[:server_context]
        calendar_repository = server_context&.dig(:calendar_repository)
        
        calendar_repository || raise(InterfaceAdapters::DependencyInjectionError, "calendar_repository not found in server_context")
      end

      def extract_filter_service(context)
        server_context = context[:server_context]
        filter_service = server_context&.dig(:filter_service)
        
        filter_service || raise(InterfaceAdapters::DependencyInjectionError, "filter_service not found in server_context")
      end

      def extract_analyzer_service(context)
        server_context = context[:server_context]
        analyzer_service = server_context&.dig(:analyzer_service)
        
        analyzer_service || raise(InterfaceAdapters::DependencyInjectionError, "analyzer_service not found in server_context")
      end

      # TODO:これここなのか気になる。デコレータとか？
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
