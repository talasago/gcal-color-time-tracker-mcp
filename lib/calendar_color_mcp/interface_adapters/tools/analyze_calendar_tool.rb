require 'mcp'
require_relative 'base_tool'
require_relative '../../application/use_cases/analyze_calendar_use_case'
require_relative '../../domain/entities/color_constants'
require_relative '../errors'
require_relative '../presenters/calendar_analysis_presenter'
require_relative '../../application/errors'

module InterfaceAdapters
  class AnalyzeCalendarTool < BaseTool
    description "Analyze Google Calendar events by color for the specified period. You can specify target colors to include or exclude."

    input_schema(
      type: "object",
      properties: {
        start_date: {
          type: "string",
          description: "Start date (YYYY-MM-DD format)"
        },
        end_date: {
          type: "string",
          description: "End date (YYYY-MM-DD format)"
        },
        include_colors: {
          type: "array",
          description: "Colors to include in analysis (specify color ID (1-11) or color name)",
          items: {
            oneOf: [
              { type: "integer", minimum: 1, maximum: 11 },
              { type: "string", enum: Domain::ColorConstants.all_valid_color_names }
            ]
          }
        },
        exclude_colors: {
          type: "array",
          description: "Colors to exclude from analysis (specify color ID (1-11) or color name)",
          items: {
            oneOf: [
              { type: "integer", minimum: 1, maximum: 11 },
              { type: "string", enum: Domain::ColorConstants.all_valid_color_names }
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
          use_case = Application::AnalyzeCalendarUseCase.new(
            calendar_repository: extract_calendar_repository(context),
            token_repository: extract_token_repository(context)
          )

          result = use_case.execute(
            start_date: start_date,
            end_date: end_date,
            include_colors: include_colors,
            exclude_colors: exclude_colors,
          )

          success_response({
            period: {
              start_date: result[:parsed_start_date].to_s,
              end_date: result[:parsed_end_date].to_s,
              days: (result[:parsed_end_date] - result[:parsed_start_date]).to_i + 1
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
          error_response("An unexpected error occurred: #{e.message}")
        end
      end

      private

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
