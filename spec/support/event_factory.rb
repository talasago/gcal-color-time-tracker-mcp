# frozen_string_literal: true

require 'date'
require 'rspec/mocks'
require_relative '../../lib/calendar_color_mcp/domain/entities/calendar_event'
require_relative '../../lib/calendar_color_mcp/domain/entities/color_constants'

class EventFactory
  extend RSpec::Mocks::ExampleMethods

  def self.timed_event(
    summary: 'テストイベント',
    color_id: Domain::ColorConstants::COLOR_NAMES[2], # 緑
    start_time: DateTime.new(2025, 1, 1, 10, 0, 0),
    duration_hours: 1.0
  )
    end_time = start_time + (duration_hours / 24.0)
    
    start_obj = RSpec::Mocks::Double.new('start')
    allow(start_obj).to receive(:date_time).and_return(start_time)
    allow(start_obj).to receive(:date).and_return(nil)
    
    end_obj = RSpec::Mocks::Double.new('end')
    allow(end_obj).to receive(:date_time).and_return(end_time)
    allow(end_obj).to receive(:date).and_return(nil)

    Domain::CalendarEvent.new(
      summary: summary,
      start_time: start_obj,
      end_time: end_obj,
      color_id: color_id&.to_s
    )
  end

  def self.all_day_event(
    summary: '全日イベント',
    color_id: Domain::ColorConstants::COLOR_NAMES[3], # 紫
    start_date: '2025-01-01',
    duration_days: 1
  )
    end_date = Date.parse(start_date) + duration_days
    end_date_str = end_date.strftime('%Y-%m-%d')
    
    start_obj = RSpec::Mocks::Double.new('start')
    allow(start_obj).to receive(:date_time).and_return(nil)
    allow(start_obj).to receive(:date).and_return(start_date)
    
    end_obj = RSpec::Mocks::Double.new('end')
    allow(end_obj).to receive(:date_time).and_return(nil)
    allow(end_obj).to receive(:date).and_return(end_date_str)

    Domain::CalendarEvent.new(
      summary: summary,
      start_time: start_obj,
      end_time: end_obj,
      color_id: color_id&.to_s
    )
  end

  def self.unknown_time_event(
    summary: '不明時間イベント',
    color_id: Domain::ColorConstants::COLOR_NAMES[5] # 黄
  )
    start_obj = RSpec::Mocks::Double.new('start')
    allow(start_obj).to receive(:date_time).and_return(nil)
    allow(start_obj).to receive(:date).and_return(nil)
    
    end_obj = RSpec::Mocks::Double.new('end')
    allow(end_obj).to receive(:date_time).and_return(nil)
    allow(end_obj).to receive(:date).and_return(nil)

    Domain::CalendarEvent.new(
      summary: summary,
      start_time: start_obj,
      end_time: end_obj,
      color_id: color_id&.to_s
    )
  end

  # 色名から色IDを取得するヘルパーメソッド
  def self.color_id_by_name(color_name)
    Domain::ColorConstants::NAME_TO_ID[color_name]
  end

  # よく使う色の定数
  LAVENDER = color_id_by_name('薄紫')  # 1
  GREEN = color_id_by_name('緑')       # 2  
  PURPLE = color_id_by_name('紫')      # 3
  RED = color_id_by_name('赤')         # 4
  YELLOW = color_id_by_name('黄')      # 5
  ORANGE = color_id_by_name('オレンジ') # 6
  CYAN = color_id_by_name('水色')      # 7
  GRAY = color_id_by_name('灰色')      # 8
  BLUE = color_id_by_name('青')        # 9
  DARK_GREEN = color_id_by_name('濃い緑') # 10
  DARK_RED = color_id_by_name('濃い赤')   # 11
end