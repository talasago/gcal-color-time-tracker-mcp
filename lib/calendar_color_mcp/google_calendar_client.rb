require 'google/apis/calendar_v3'
require 'googleauth'
require 'date'
require 'time'
require_relative 'token_manager'
require_relative 'errors'
require_relative 'loggable'

module CalendarColorMCP
  class GoogleCalendarClient
    include Loggable

    SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

    def initialize
      @service = Google::Apis::CalendarV3::CalendarService.new
      @token_manager = TokenManager.instance
      @authenticated = false
    end

    # FIXME:ビジネスロジックが含まれていることが問題
    def get_events(start_date, end_date)
      authenticate

      start_time = Time.new(start_date.year, start_date.month, start_date.day, 0, 0, 0)
      end_time = Time.new(end_date.year, end_date.month, end_date.day, 23, 59, 59)

      all_events = @service.list_events(
        'primary',
        time_min: start_time.iso8601,
        time_max: end_time.iso8601,
        single_events: true,
        order_by: 'startTime'
      ).items

      # 参加したイベントのみをフィルタリング
      attended_events = filter_attended_events(all_events)

      logger.debug "=== Google Calendar API レスポンス デバッグ ==="
      logger.debug "認証ユーザー: #{@user_email}"
      logger.debug "取得期間: #{start_date} 〜 #{end_date}"
      logger.debug "全イベント数: #{all_events.length}"
      logger.debug "参加イベント数: #{attended_events.length}"
      logger.debug "除外イベント数: #{all_events.length - attended_events.length}"

      attended_events.each_with_index do |event, index|
        logger.debug "--- 参加イベント #{index + 1} ---"
        logger.debug "タイトル: #{event.summary}"
        logger.debug "color_id: #{event.color_id.inspect}"
        logger.debug "start.date_time: #{event.start.date_time.inspect}"
        logger.debug "start.date: #{event.start.date.inspect}"
        logger.debug "end.date_time: #{event.end.date_time.inspect}"
        logger.debug "end.date: #{event.end.date.inspect}"
        logger.debug "参加状況: #{get_attendance_status(event)}"
      end
      logger.debug "=" * 50

      attended_events
    rescue Google::Apis::AuthorizationError => e
      raise AuthenticationError, "認証の更新が必要です: #{e.message}"
    rescue Google::Apis::ClientError, Google::Apis::ServerError => e
      raise CalendarApiError, "カレンダーAPIエラー: #{e.message}"
    rescue => e
      raise CalendarApiError, "カレンダーイベントの取得に失敗しました: #{e.message}"
    end

    private

    def authenticate
      return true if @authenticated

      begin
        authorize_service
        @user_email = get_user_email
        @authenticated = true
        true
      rescue
        @authenticated = false
        @user_email = nil
        raise
      end
    end

    def get_user_email
      calendar_info = @service.get_calendar('primary')
      calendar_info.id
    rescue => e
      # FIXME:例外を握りつぶしていいのか？
      logger.debug "ユーザーメール取得エラー: #{e.message}"
      nil
    end

    def filter_attended_events(events)
      events.select { |event| attended_event?(event) }
    end

    def attended_event?(event)
      # 主催者の場合は自動的に参加とみなす
      return true if event.organizer&.self

      # 参加者情報がない場合（プライベートイベント）は参加とみなす
      return true if event.attendees.nil? || event.attendees.empty?

      # 参加者リストから自分の参加状況を確認
      user_attendee = event.attendees.find { |attendee|
        attendee.email == @user_email || attendee.self
      }

      if user_attendee
        # 参加承認している場合のみ true
        user_attendee.response_status == 'accepted'
      else
        # 参加者リストにいない場合は参加とみなす（プライベートイベントなど）
        true
      end
    end

    def get_attendance_status(event)
      if event.organizer&.self
        "主催者"
      elsif event.attendees.nil? || event.attendees.empty?
        "プライベートイベント"
      else
        user_attendee = event.attendees.find { |attendee|
          attendee.email == @user_email || attendee.self
        }

        if user_attendee
          case user_attendee.response_status
          when 'accepted' then '参加承認'
          when 'declined' then '参加辞退'
          when 'tentative' then '仮承認'
          when 'needsAction' then '未応答'
          else user_attendee.response_status || '不明'
          end
        else
          "参加者リストなし"
        end
      end
    end

    def authorize_service
      credentials = @token_manager.load_credentials
      raise AuthenticationError, "認証情報が見つかりません" unless credentials

      @service.authorization = credentials

      # トークンの有効性確認
      if credentials.expired?
        begin
          credentials.refresh!
        rescue Google::Apis::AuthorizationError => e
          raise AuthenticationError, "トークンの更新に失敗しました: #{e.message}"
        end
        @token_manager.save_credentials(credentials)
      end
    rescue Google::Apis::AuthorizationError => e
      raise AuthenticationError, "認証エラー: #{e.message}"
    end
  end
end
