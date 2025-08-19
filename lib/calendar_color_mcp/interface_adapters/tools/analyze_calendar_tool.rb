require 'mcp'
require_relative 'base_tool'
require_relative '../../application/use_cases/analyze_calendar_use_case'
require_relative '../../domain/entities/color_constants'
require_relative '../errors'
require_relative '../presenters/calendar_analysis_presenter'

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
              { type: "string", enum: Domain::ColorConstants.color_names_array }
            ]
          }
        },
        exclude_colors: {
          type: "array",
          description: "集計除外の色（色ID(1-11)またはカラー名を指定）",
          items: {
            oneOf: [
              { type: "integer", minimum: 1, maximum: 11 },
              { type: "string", enum: Domain::ColorConstants.color_names_array }
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
            token_repository: extract_token_repository(context)
          )

          result = use_case.execute(
            start_date: parsed_start_date,
            end_date: parsed_end_date,
            color_filters: color_filters,
          )

          success_response({
            period: {
              start_date: parsed_start_date.to_s,
              end_date: parsed_end_date.to_s,
              days: (parsed_end_date - parsed_start_date).to_i + 1
            },
            color_filter: build_filter_summary(include_colors, exclude_colors),
            analysis: result[:color_breakdown],
            summary: result[:summary],
            formatted_output: Presenters::CalendarAnalysisPresenter.format_text(
              result,
              include_colors: include_colors,
              exclude_colors: exclude_colors
            )
          })

        rescue Application::AuthenticationRequiredError => e
          logger.debug "Authentication error: #{e.message}"
          oauth_service = extract_oauth_service(context)
          auth_url = oauth_service.generate_auth_url
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

      # これユースケースの責務かも
      def build_color_filters(include_colors, exclude_colors)
        return nil unless include_colors || exclude_colors

        filters = {}
        filters[:include_colors] = include_colors if include_colors
        filters[:exclude_colors] = exclude_colors if exclude_colors
        filters
      end

      def build_filter_summary(include_colors, exclude_colors)
        {
          has_filters: !!(include_colors || exclude_colors),
          include_colors: include_colors,
          exclude_colors: exclude_colors
        }
      end
    end
  end
end
