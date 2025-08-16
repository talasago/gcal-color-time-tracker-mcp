require 'google/apis/calendar_v3'
require_relative '../../errors'
require_relative '../../loggable'

module Infrastructure
  class GoogleCalendarRepository
    def initialize
      @service = Google::Apis::CalendarV3::CalendarService.new
    end

    def fetch_events(start_date, end_date)
      start_time = Time.new(start_date.year, start_date.month, start_date.day, 0, 0, 0)
      end_time = Time.new(end_date.year, end_date.month, end_date.day, 23, 59, 59)

      response = @service.list_events(
        'primary',
        time_min: start_time.iso8601,
        time_max: end_time.iso8601,
        single_events: true,
        order_by: 'startTime'
      )

      response.items
    rescue Google::Apis::ClientError, Google::Apis::ServerError => e
      raise CalendarColorMCP::CalendarApiError, "カレンダーAPIエラー: #{e.message}"
    rescue => e
      raise CalendarColorMCP::CalendarApiError, "カレンダーイベントの取得に失敗しました: #{e.message}"
    end

    # NOTE: TODO: そもそもpublicメソッド？？にする必要があるのか？
    # 1. calendar_infoがnilになるケース: 通常は認証済みであれば発生しませんが、API仕様上は可能性があります
    # . calendar_info.idがnilになるケース: カレンダー情報は取得できてもIDフィールドが空の場合があります
    def get_user_email
      calendar_info = @service.get_calendar('primary')
      calendar_info.id
    rescue Google::Apis::ClientError, Google::Apis::ServerError => e
      raise CalendarColorMCP::CalendarApiError, "ユーザー情報の取得に失敗しました: #{e.message}"
    rescue => e
      raise CalendarColorMCP::CalendarApiError, "ユーザーメール取得エラー: #{e.message}"
    end

    # TODO: そもそもpublicメソッド？？にする必要があるのか？
    def authorize(credentials)
      @service.authorization = credentials
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
    
    def authorize(credentials)
      logger.debug "Authorizing repository with credentials"
      @repository.authorize(credentials)
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
      logger.debug "start.date_time: #{event.start.date_time.inspect}"
      logger.debug "start.date: #{event.start.date.inspect}"
      logger.debug "end.date_time: #{event.end.date_time.inspect}"
      logger.debug "end.date: #{event.end.date.inspect}"
    end
  end
end
