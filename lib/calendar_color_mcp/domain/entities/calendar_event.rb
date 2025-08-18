# frozen_string_literal: true

module Domain
  class CalendarEvent
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
      # TODO:端数が出ないように計算できないものかな。時間を足したいだけなので。時間計算のライブラリとか無いかな。
      # そもそもこのメソッド使うのか？？
      return 0 unless @start_time && @end_time
      (@end_time - @start_time) / 3600.0
    end

    def attended_by?(user_email)
      return true if organized_by_user?
      return true if private_event?

      user_attendee = find_user_attendee(user_email)
      return false unless user_attendee
      user_attendee.accepted?
    end


    def color_name
      Domain::ColorConstants::COLOR_NAMES[@color_id] || Domain::ColorConstants::COLOR_NAMES[Domain::ColorConstants::DEFAULT_COLOR_ID]
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
  end
end
