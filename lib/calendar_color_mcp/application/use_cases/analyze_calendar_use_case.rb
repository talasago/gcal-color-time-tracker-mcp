require_relative '../errors'
require_relative '../../infrastructure/repositories/token_repository'
require_relative '../../infrastructure/repositories/google_calendar_repository'
require_relative '../../domain/services/event_filter_service'
require_relative '../../domain/services/time_analysis_service'

module Application
  class AnalyzeCalendarUseCase
    def initialize(
      # FIXME: Infra層を知っているのは良くない
      calendar_repository: Infrastructure::GoogleCalendarRepositoryLogDecorator.new(
        Infrastructure::GoogleCalendarRepository.new
      ),
      token_repository: Infrastructure::TokenRepository.instance,
      filter_service: Domain::EventFilterService.new,
      analyzer_service: Domain::TimeAnalysisService.new
    )
      @calendar_repository = calendar_repository
      @token_repository = token_repository
      @filter_service = filter_service
      @analyzer_service = analyzer_service
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
        raise Application::AuthenticationRequiredError, "認証が必要です"
      end
    end

    def validate_and_parse_dates(start_date, end_date)
      # Application層での直接日付バリデーション（YAGNI原則に従った設計）
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
        # 認証エラーの場合は再発生させる
        raise e
      rescue
        # TODO:: 認証エラー時もフィルタリングで処理されるか知りたい
        # その他のエラー時はnilを返す（フィルタリング処理側で適切に処理される）
        nil
      end
    end
  end
end
