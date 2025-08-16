require_relative '../errors'
require_relative '../../errors'
require_relative '../../token_manager'
require_relative '../../google_calendar_auth_manager'

module Application
  class AnalyzeCalendarUseCase
    def initialize(
      calendar_repository: nil,
      filter_service: nil,
      analyzer_service: nil,
      token_manager: CalendarColorMCP::TokenManager.instance,
      auth_manager: CalendarColorMCP::GoogleCalendarAuthManager.instance
    )
      @calendar_repository = calendar_repository
      @filter_service = filter_service
      @analyzer_service = analyzer_service
      @token_manager = token_manager
      @auth_manager = auth_manager
    end

    def execute(start_date:, end_date:, color_filters: nil, user_email:)
      validate_date_range(start_date, end_date)
      ensure_authenticated
      events = @calendar_repository.fetch_events(start_date, end_date)
      filtered_events = @filter_service.apply_filters(events, color_filters, user_email)
      @analyzer_service.analyze(filtered_events)
    rescue Application::AuthenticationRequiredError => e
      raise Application::AuthenticationRequiredError, e.message
    end

    private

    def ensure_authenticated
      unless @token_manager.token_exist?
        raise Application::AuthenticationRequiredError, "認証が必要です"
      end
    end

    def validate_date_range(start_date, end_date)
      # TODO:バリデーションがこのusecaseの役割なのか気になるなあ。
      if start_date.nil? || end_date.nil?
        raise Application::InvalidParameterError, "Both start date and end date must be provided"
      end
    end
  end
end
