# frozen_string_literal: true

require 'date'
require 'rspec/mocks'
require_relative '../../lib/calendar_color_mcp/domain/entities/calendar_event'
require_relative '../../lib/calendar_color_mcp/domain/entities/color_constants'

class EventFactory
  extend RSpec::Mocks::ExampleMethods

  def self.timed_event(
    summary: 'テストイベント',
    color_id: 2, # Sage (緑)
    start_time: DateTime.new(2025, 1, 1, 10, 0, 0),
    duration_hours: 1.0
  )
    end_time = start_time + Rational(duration_hours, 24)

    Domain::CalendarEvent.new(
      summary: summary,
      start_time: start_time,
      end_time: end_time,
      color_id: color_id
    )
  end

  def self.all_day_event(
    summary: '全日イベント',
    color_id: 3, # Grape (紫)
    start_date: '2025-01-01',
    duration_days: 1
  )
    start_time = Date.parse(start_date).to_time
    end_time = (Date.parse(start_date) + duration_days).to_time

    Domain::CalendarEvent.new(
      summary: summary,
      start_time: start_time,
      end_time: end_time,
      color_id: color_id
    )
  end

  def self.unknown_time_event(
    summary: '不明時間イベント',
    color_id: 5 # Banana (黄)
  )
    Domain::CalendarEvent.new(
      summary: summary,
      start_time: nil,
      end_time: nil,
      color_id: color_id
    )
  end

  # 色名から色IDを取得するヘルパーメソッド（日本語色名対応）
  def self.color_id_by_japanese_name(color_name)
    Domain::ColorConstants.combined_name_to_id[color_name]
  end

  # よく使う色の定数（日本語色名で取得）
  LAVENDER = color_id_by_japanese_name('薄紫')  # 1
  GREEN = color_id_by_japanese_name('緑')       # 2
  PURPLE = color_id_by_japanese_name('紫')      # 3
  RED = color_id_by_japanese_name('赤')         # 4
  YELLOW = color_id_by_japanese_name('黄')      # 5
  ORANGE = color_id_by_japanese_name('オレンジ') # 6
  CYAN = color_id_by_japanese_name('水色')      # 7
  GRAY = color_id_by_japanese_name('灰色')      # 8
  BLUE = color_id_by_japanese_name('青')        # 9
  DARK_GREEN = color_id_by_japanese_name('濃い緑') # 10
  DARK_RED = color_id_by_japanese_name('濃い赤')   # 11

  # API応答モックオブジェクト作成メソッド
  def self.simple_api_event(overrides = {})
    defaults = {
      summary: 'Test Event',
      color_id: '1',
      start_time: Time.parse('2024-01-01 10:00:00'),
      end_time: Time.parse('2024-01-01 11:00:00'),
      attendees: [],
      organizer: nil
    }
    create_api_event(defaults.merge(overrides))
  end

  def self.api_event_with_attendees(overrides = {})
    defaults = {
      summary: 'Meeting with Attendees',
      color_id: '2',
      attendees: [accepted_attendee, declined_self_attendee],
      organizer: organizer_not_self
    }
    simple_api_event(defaults.merge(overrides))
  end

  def self.api_event_with_nil_values(overrides = {})
    defaults = {
      summary: 'Event with nil values',
      color_id: '3',
      attendees: nil,
      organizer: nil
    }
    simple_api_event(defaults.merge(overrides))
  end

  def self.all_day_api_event(overrides = {})
    defaults = {
      summary: 'All Day Event',
      color_id: '4',
      is_all_day: true,
      start_time: Time.parse('2024-01-04 00:00:00'),
      end_time: Time.parse('2024-01-05 00:00:00')
    }
    simple_api_event(defaults.merge(overrides))
  end

  def self.api_event_with_invalid_data(overrides = {})
    defaults = {
      summary: nil,
      color_id: 'invalid',
      attendees: [attendee_without_email],
      organizer: organizer_without_email
    }
    simple_api_event(defaults.merge(overrides))
  end

  private

  def self.create_api_event(attrs)
    double('api_event').tap do |event|
      allow(event).to receive(:summary).and_return(attrs[:summary])
      allow(event).to receive(:color_id).and_return(attrs[:color_id])
      allow(event).to receive(:attendees).and_return(attrs[:attendees])
      allow(event).to receive(:organizer).and_return(attrs[:organizer])

      if attrs[:is_all_day]
        start_obj = double('start')
        allow(start_obj).to receive(:date_time).and_return(nil)
        allow(start_obj).to receive(:date).and_return(attrs[:start_time].to_date.to_s)
        allow(event).to receive(:start).and_return(start_obj)

        end_obj = double('end')
        allow(end_obj).to receive(:date_time).and_return(nil)
        allow(end_obj).to receive(:date).and_return(attrs[:end_time].to_date.to_s)
        allow(event).to receive(:end).and_return(end_obj)
      else
        start_obj = double('start')
        allow(start_obj).to receive(:date_time).and_return(attrs[:start_time])
        allow(start_obj).to receive(:date).and_return(nil)
        allow(event).to receive(:start).and_return(start_obj)

        end_obj = double('end')
        allow(end_obj).to receive(:date_time).and_return(attrs[:end_time])
        allow(end_obj).to receive(:date).and_return(nil)
        allow(event).to receive(:end).and_return(end_obj)
      end
    end
  end

  def self.accepted_attendee
    double('attendee').tap do |attendee|
      allow(attendee).to receive(:email).and_return('attendee1@example.com')
      allow(attendee).to receive(:response_status).and_return('accepted')
      allow(attendee).to receive(:self).and_return(false)
    end
  end

  def self.declined_self_attendee
    double('attendee').tap do |attendee|
      allow(attendee).to receive(:email).and_return('attendee2@example.com')
      allow(attendee).to receive(:response_status).and_return('declined')
      allow(attendee).to receive(:self).and_return(true)
    end
  end

  def self.attendee_without_email
    double('attendee').tap do |attendee|
      allow(attendee).to receive(:email).and_return(nil)
      allow(attendee).to receive(:response_status).and_return('accepted')
      allow(attendee).to receive(:self).and_return(false)
    end
  end

  def self.organizer_not_self
    double('organizer').tap do |organizer|
      allow(organizer).to receive(:email).and_return('organizer@example.com')
      allow(organizer).to receive(:display_name).and_return('Meeting Organizer')
      allow(organizer).to receive(:self).and_return(false)
    end
  end

  def self.organizer_without_email
    double('organizer').tap do |organizer|
      allow(organizer).to receive(:email).and_return(nil)
      allow(organizer).to receive(:display_name).and_return('Invalid Organizer')
      allow(organizer).to receive(:self).and_return(false)
    end
  end
end
