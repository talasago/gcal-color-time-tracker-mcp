require 'google/apis/calendar_v3'
require 'googleauth'
require 'date'
require 'time'

module CalendarColorMCP
  class GoogleCalendarClient
    SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

    def initialize(user_id)
      @user_id = user_id
      @service = Google::Apis::CalendarV3::CalendarService.new
      @user_manager = UserManager.new
      authorize_service
    end

    def get_events(start_date, end_date)
      start_time = Time.new(start_date.year, start_date.month, start_date.day, 0, 0, 0)
      end_time = Time.new(end_date.year, end_date.month, end_date.day, 23, 59, 59)
      
      @service.list_events(
        'primary',
        time_min: start_time.rfc3339,
        time_max: end_time.rfc3339,
        single_events: true,
        order_by: 'startTime'
      ).items
    rescue Google::Apis::AuthorizationError => e
      raise e
    rescue => e
      raise "カレンダーイベントの取得に失敗しました: #{e.message}"
    end

    private

    def authorize_service
      credentials = @user_manager.load_credentials(@user_id)
      raise Google::Apis::AuthorizationError, "認証情報が見つかりません" unless credentials
      
      @service.authorization = credentials
      
      # トークンの有効性確認
      if credentials.expired?
        credentials.refresh!
        @user_manager.save_credentials(@user_id, credentials)
      end
    end
  end
end