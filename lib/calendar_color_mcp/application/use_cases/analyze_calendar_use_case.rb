require_relative '../errors'
require_relative '../../domain/services/event_filter_service'
require_relative '../../domain/services/time_analysis_service'

module Application
  class AnalyzeCalendarUseCase
    def initialize(calendar_repository:, token_repository:)
      @calendar_repository = calendar_repository
      @token_repository = token_repository
      @filter_service = Domain::EventFilterService.new
      @analyzer_service = Domain::TimeAnalysisService.new
    end

    def execute(start_date:, end_date:, include_colors: nil, exclude_colors: nil)
      parsed_start_date, parsed_end_date = validate_and_parse_dates(start_date, end_date)
      ensure_authenticated

      events = @calendar_repository.fetch_events(parsed_start_date, parsed_end_date)
      filtered_events = @filter_service.apply_filters(events, get_user_email, 
                                                     include_colors: include_colors, 
                                                     exclude_colors: exclude_colors)
      @analyzer_service.analyze(filtered_events).merge(
        parsed_start_date: parsed_start_date,
        parsed_end_date: parsed_end_date
      )
    rescue Application::AuthenticationRequiredError => e
      raise Application::AuthenticationRequiredError, e.message
    end

    private


    def ensure_authenticated
      unless @token_repository.token_exist?
        raise Application::AuthenticationRequiredError, "Authentication required"
      end
    end

    def validate_and_parse_dates(start_date, end_date)
      # Direct date validation at Application layer (following YAGNI principle)
      if start_date.nil? || end_date.nil?
        raise Application::InvalidParameterError, "Both start date and end date must be provided"
      end

      begin
        parsed_start = Date.parse(start_date.to_s)
        parsed_end = Date.parse(end_date.to_s)
      rescue ArgumentError => e
        raise Application::InvalidParameterError, "Invalid date format: #{e.message}"
      end

      if parsed_end < parsed_start
        raise Application::InvalidParameterError, "End date must be after start date"
      end

      [parsed_start, parsed_end]
    end

    def get_user_email
      begin
        @calendar_repository.get_user_email
      rescue Application::AuthenticationRequiredError => e
        # Re-raise authentication errors
        raise e
      rescue
        # TODO: Need to check if authentication errors are also handled by filtering
        # For other errors, return nil (will be handled appropriately by filtering layer)
        nil
      end
    end
  end
end
