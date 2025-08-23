# frozen_string_literal: true

require_relative '../../loggable'

module Domain
  class CalendarEvent
    include CalendarColorMCP::Loggable

    attr_reader :summary, :start_time, :end_time, :color_id, :attendees, :organizer

    def initialize(summary:, start_time:, end_time:, color_id:, attendees: [], organizer: nil)
      @summary = summary
      @start_time = start_time
      @end_time = end_time
      @color_id = color_id
      @attendees = attendees
      @organizer = organizer
    end

    def duration_hours
      # NOTE: 端数は呼び出し元で処理してモラル
      log_duration_start
      return 0.0 unless @start_time && @end_time

      duration = if time_object_format?
        calculate_time_object_duration
      elsif google_api_format?
        calculate_google_api_duration
      else
        log_unknown_format
        0.0
      end

      log_duration_end(duration)
      duration
    end

    def attended_by?(user_email)
      return true if organized_by_user?
      return true if private_event?

      user_attendee = find_user_attendee(user_email)
      return false unless user_attendee
      user_attendee.accepted?
    end


    def color_name
      Domain::ColorConstants.color_name(@color_id) || Domain::ColorConstants.color_name(Domain::ColorConstants.default_color_id)
    end

    def all_day?
      return false unless @start_time && @end_time

      if google_api_format?
        # Google Calendar APIの場合: dateフィールドが設定されていて、date_timeフィールドがnilの場合は終日イベント
        if @start_time.date && @start_time.date_time.nil? && @end_time.date && @end_time.date_time.nil?
          true
        else
          false
        end
      else
        # Time/DateTimeオブジェクトの場合: 開始時刻が00:00:00で終了時刻が23:59:59または翌日の00:00:00の場合
        # ただし、これは推測ベースなので完全ではない
        @start_time.hour == 0 && @start_time.min == 0 && @start_time.sec == 0 &&
        ((@end_time.hour == 23 && @end_time.min == 59) || (@end_time.hour == 0 && @end_time.min == 0 && @end_time.sec == 0))
      end
    end

    private

    def organized_by_user?
      @organizer&.self?
    end

    def private_event?
      @attendees.nil? || @attendees.empty?
    end

    def find_user_attendee(user_email)
      @attendees&.find { |attendee| attendee.email == user_email || attendee.self? }
    end

    def time_object_format?
      (@start_time.is_a?(Time) || @start_time.is_a?(DateTime)) && 
      (@end_time.is_a?(Time) || @end_time.is_a?(DateTime))
    end

    def google_api_format?
      @start_time.respond_to?(:date_time) && @start_time.respond_to?(:date) &&
        @end_time.respond_to?(:date_time) && @end_time.respond_to?(:date)
    end

    def calculate_time_object_duration
      logger.debug "Format: Time objects"
      
      # DateTime同士の減算は日単位のRationalを返すため、時間単位に変換
      # Time同士の減算は秒単位のFloatを返すため、秒から時間に変換
      calculated_duration = if @start_time.is_a?(DateTime) || @end_time.is_a?(DateTime)
        (@end_time - @start_time) * 24  # 日単位から時間単位に変換
      else
        (@end_time - @start_time) / 3600.0  # 秒単位から時間単位に変換
      end
      
      logger.debug "calculated_duration: #{calculated_duration} hours"
      calculated_duration
    end

    def calculate_google_api_duration
      logger.debug "Format: Google Calendar API"
      log_google_api_fields

      duration = if @start_time.date_time && @end_time.date_time
        calculate_timed_event_duration
      elsif @start_time.date && @end_time.date
        calculate_all_day_event_duration
      else
        log_unknown_time_type
        0.0
      end

      logger.debug "Google API duration result: #{duration} hours"
      duration
    end

    def calculate_timed_event_duration
      duration_seconds = @end_time.date_time - @start_time.date_time
      duration_seconds_float = duration_seconds * 86400
      calculated_duration = duration_seconds_float / 3600.0

      logger.debug "Type: Timed event"
      logger.debug "duration_seconds (Rational): #{duration_seconds}"
      logger.debug "duration_seconds_float: #{duration_seconds_float} seconds"
      logger.debug "calculated_duration: #{calculated_duration} hours"

      calculated_duration
    end

    def calculate_all_day_event_duration
      start_date = Date.parse(@start_time.date)
      end_date = Date.parse(@end_time.date)
      calculated_duration = (end_date - start_date).to_i * 24.0

      logger.debug "Type: All-day event"
      logger.debug "start_date: #{start_date}"
      logger.debug "end_date: #{end_date}"
      logger.debug "Days: #{(end_date - start_date).to_i}"
      logger.debug "calculated_duration: #{calculated_duration} hours"

      calculated_duration
    end

    def log_duration_start
      logger.debug "--- Duration Calculation Debug (CalendarEvent) ---"
      logger.debug "Event: #{@summary}"
      logger.debug "start_time: #{@start_time.inspect}"
      logger.debug "end_time: #{@end_time.inspect}"
    end

    def log_duration_end(duration)
      logger.debug "Final duration: #{duration} hours"
      logger.debug "---"
    end

    def log_google_api_fields
      logger.debug "start.date_time: #{@start_time.date_time.inspect}"
      logger.debug "start.date: #{@start_time.date.inspect}"
      logger.debug "end.date_time: #{@end_time.date_time.inspect}"
      logger.debug "end.date: #{@end_time.date.inspect}"
    end

    def log_unknown_format
      logger.debug "Format: Unknown"
    end

    def log_unknown_time_type
      logger.debug "Type: Unknown time"
    end
  end
end
