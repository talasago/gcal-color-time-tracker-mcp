require 'google/apis/calendar_v3'
require_relative '../errors'
require_relative '../../application/errors'
require_relative '../../loggable'
require_relative 'token_repository'
require_relative '../../domain/entities/calendar_event'
require_relative '../../domain/entities/attendee'
require_relative '../../domain/entities/organizer'
require_relative '../../domain/entities/color_constants'

module Infrastructure
  class GoogleCalendarRepository
    def initialize
      @service = Google::Apis::CalendarV3::CalendarService.new
      @token_repository = TokenRepository.instance
    end

    def fetch_events(start_date, end_date)
      authorize
      start_time = Time.new(start_date.year, start_date.month, start_date.day, 0, 0, 0)
      end_time = Time.new(end_date.year, end_date.month, end_date.day, 23, 59, 59)

      response = @service.list_events(
        'primary',
        time_min: start_time.iso8601,
        time_max: end_time.iso8601,
        single_events: true,
        order_by: 'startTime'
      )

      # Google API Event → Domain::CalendarEvent変換
      response.items.map { |api_event| convert_to_domain_event(api_event) }
    rescue Google::Apis::AuthorizationError, Application::AuthenticationRequiredError => e
      raise Application::AuthenticationRequiredError, "認証エラー: #{e.message}"
    rescue Google::Apis::ClientError, Google::Apis::ServerError => e
      raise Infrastructure::ExternalServiceError, "カレンダーAPIエラー: #{e.message}"
    rescue => e
      raise Infrastructure::ExternalServiceError, "カレンダーイベントの取得に失敗しました: #{e.message}"
    end

    # NOTE: TODO:
    # 1. calendar_infoがnilになるケース: 通常は認証済みであれば発生しませんが、API仕様上は可能性があります
    # . calendar_info.idがnilになるケース: カレンダー情報は取得できてもIDフィールドが空の場合があります
    def get_user_email
      calendar_info = @service.get_calendar('primary')
      calendar_info.id
    rescue Google::Apis::AuthorizationError => e
      raise Application::AuthenticationRequiredError, "認証エラー: #{e.message}"
    rescue Google::Apis::ClientError, Google::Apis::ServerError => e
      raise Infrastructure::ExternalServiceError, "ユーザー情報の取得に失敗しました: #{e.message}"
    rescue => e
      raise Infrastructure::ExternalServiceError, "ユーザーメール取得エラー: #{e.message}"
    end

    private

    def authorize
      credentials = load_credentials
      set_authorization(credentials)
    end

    def load_credentials
      begin
        credentials = @token_repository.load_credentials
      rescue => e
        raise Infrastructure::ExternalServiceError, "認証情報の検証に失敗しました: #{e.message}"
      end
      raise Application::AuthenticationRequiredError, "認証情報が見つかりません" unless credentials

      refresh_if_expired(credentials)
      credentials
    end

    def refresh_if_expired(credentials)
      return unless credentials.expired?

      credentials.refresh!
      @token_repository.save_credentials(credentials)
    rescue Google::Apis::AuthorizationError => e
      raise Application::AuthenticationRequiredError, "トークンのリフレッシュに失敗しました: #{e.message}"
    rescue => e
      raise Infrastructure::ExternalServiceError, "認証情報の保存に失敗しました: #{e.message}"
    end

    def set_authorization(credentials)
      @service.authorization = credentials
    rescue => e
      raise Infrastructure::ExternalServiceError, "認証設定に失敗しました: #{e.message}"
    end

    def convert_to_domain_event(api_event)
      Domain::CalendarEvent.new(
        summary: api_event.summary,
        start_time: extract_start_time(api_event),
        end_time: extract_end_time(api_event),
        color_id: api_event.color_id&.to_i || Domain::ColorConstants::DEFAULT_COLOR_ID, # FIXME:これデフォルトを代入していいか？
        attendees: convert_attendees(api_event.attendees),
        organizer: convert_organizer(api_event.organizer)
      )
    end

    def extract_start_time(api_event)
      if api_event.start.date_time
        api_event.start.date_time
      elsif api_event.start.date
        Date.parse(api_event.start.date).to_time
      else
        nil
      end
    end

    def extract_end_time(api_event)
      if api_event.end.date_time
        api_event.end.date_time
      elsif api_event.end.date
        Date.parse(api_event.end.date).to_time
      else
        nil
      end
    end

    def convert_attendees(api_attendees)
      return [] unless api_attendees

      api_attendees.map do |api_attendee|
        Domain::Attendee.new(
          email: api_attendee.email,
          response_status: api_attendee.response_status,
          self: api_attendee.self || false
        )
      end
    end

    def convert_organizer(api_organizer)
      return nil unless api_organizer

      Domain::Organizer.new(
        email: api_organizer.email,
        display_name: api_organizer.display_name,
        self: api_organizer.self || false
      )
    end
  end

  class GoogleCalendarRepositoryLogDecorator
    include CalendarColorMCP::Loggable

    def initialize(repository)
      @repository = repository
    end

    def fetch_events(start_date, end_date)
      events = @repository.fetch_events(start_date, end_date)
      log_debug_info(events, start_date, end_date)
      events
    end

    def get_user_email
      user_email = @repository.get_user_email
      logger.debug "Retrieved user email: #{user_email}"
      user_email
    end

    def authorize
      logger.debug "Authorizing repository with credentials"
      @repository.authorize
    end

    private

    def log_debug_info(events, start_date, end_date)
      logger.debug "=== Google Calendar API Response Debug ==="
      logger.debug "Period: #{start_date} ~ #{end_date}"
      logger.debug "Total events: #{events.length}"

      log_events_details(events)
      logger.debug "=" * 50
    end

    def log_events_details(events)
      events.each_with_index do |event, index|
        logger.debug "--- Event #{index + 1} ---"
        logger.debug "Title: #{event.summary}"
        logger.debug "color_id: #{event.color_id.inspect}"
        log_event_times(event)
      end
    end

    def log_event_times(event)
      # Domain::CalendarEventオブジェクト用のログ出力
      logger.debug "start_time: #{event.start_time.inspect}"
      logger.debug "end_time: #{event.end_time.inspect}"
      logger.debug "duration_hours: #{event.duration_hours}"
    end
  end
end
