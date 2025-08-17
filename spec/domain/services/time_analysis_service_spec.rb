require 'spec_helper'
require 'date'
require_relative '../../../lib/calendar_color_mcp/domain/services/time_analysis_service'
require_relative '../../../lib/calendar_color_mcp/domain/entities/color_constants'

describe Domain::TimeAnalysisService do
  subject(:service) { described_class.new }

  def create_timed_event(summary, color_id, start_time, end_time)
    double('timed_event',
      summary: summary,
      color_id: color_id,
      start: double(date_time: start_time, date: nil),
      end: double(date_time: end_time, date: nil)
    )
  end

  def create_all_day_event(summary, color_id, start_date, end_date)
    double('all_day_event',
      summary: summary,
      color_id: color_id,
      start: double(date_time: nil, date: start_date),
      end: double(date_time: nil, date: end_date)
    )
  end

  def create_unknown_time_event(summary, color_id)
    double('unknown_time_event',
      summary: summary,
      color_id: color_id,
      start: double(date_time: nil, date: nil),
      end: double(date_time: nil, date: nil)
    )
  end

  # Shared examples for common expectations
  shared_examples 'proper summary structure' do
    it 'has correct summary structure' do
      summary_data = subject[:summary]
      expect(summary_data).to include(
        total_hours: be_a(Numeric),
        total_events: be_a(Integer)
      )
    end
  end

  describe '#analyze' do
    context 'with mixed event types' do
      let(:filtered_events) do
        [
          create_timed_event('ミーティング', '2', DateTime.new(2025, 1, 1, 9, 0, 0), DateTime.new(2025, 1, 1, 10, 30, 0)),
          create_all_day_event('会議', '3', '2025-01-01', '2025-01-02'),
          create_all_day_event('研修', '4', '2025-01-01', '2025-01-03'),
          create_unknown_time_event('不明イベント', '5'),
          create_timed_event(nil, '6', DateTime.new(2025, 1, 1, 14, 0, 0), DateTime.new(2025, 1, 1, 15, 0, 0)),
          create_timed_event('デフォルト色イベント', nil, DateTime.new(2025, 1, 1, 16, 0, 0), DateTime.new(2025, 1, 1, 17, 0, 0))
        ]
      end

      subject { service.analyze(filtered_events) }

      it 'correctly categorizes events by color' do
        color_breakdown = subject[:color_breakdown]

        expect(color_breakdown['緑']).to include(total_hours: 1.5, event_count: 1)
        expect(color_breakdown['紫']).to include(total_hours: 24.0, event_count: 1)
        expect(color_breakdown['赤']).to include(total_hours: 48.0, event_count: 1)
      end

      it 'sorts colors by total hours in descending order' do
        color_names = subject[:color_breakdown].keys
        expect(color_names.first).to eq('赤')
        expect(color_names.last).to eq('黄')
      end

      it 'handles events with no title' do
        orange_events = subject[:color_breakdown]['オレンジ'][:events]
        expect(orange_events.first[:title]).to eq('（タイトルなし）')
      end

      it 'uses default color for nil color_id' do
        expect(subject[:color_breakdown]).to have_key('青')
      end

      it 'generates correct summary' do
        summary = subject[:summary]
        expect(summary[:total_events]).to eq(6)
        expect(summary[:total_hours]).to eq(75.5)
        expect(summary[:most_used_color][:name]).to eq('赤')
      end

      it_behaves_like 'proper summary structure'
    end

    context 'with empty events' do
      let(:filtered_events) { [] }
      subject { service.analyze(filtered_events) }

      it 'returns empty analysis' do
        expect(subject[:summary][:total_events]).to eq(0)
        expect(subject[:summary][:total_hours]).to eq(0)
        expect(subject[:summary]).not_to have_key(:most_used_color)
        expect(subject[:color_breakdown]).to be_empty
      end

      it_behaves_like 'proper summary structure'
    end

    context 'with single event' do
      let(:filtered_events) { [create_timed_event('ミーティング', '2', DateTime.new(2025, 1, 1, 9, 0, 0), DateTime.new(2025, 1, 1, 10, 30, 0))] }
      subject { service.analyze(filtered_events) }

      it 'analyzes single event correctly' do
        expect(subject[:summary][:total_events]).to eq(1)
        expect(subject[:summary][:total_hours]).to eq(1.5)
        expect(subject[:summary]).to have_key(:most_used_color)
        expect(subject[:summary][:most_used_color][:percentage]).to eq(100.0)
      end

      it_behaves_like 'proper summary structure'
    end

    context 'with all zero duration events' do
      let(:filtered_events) { [create_unknown_time_event('不明1', '1'), create_unknown_time_event('不明2', '2')] }
      subject { service.analyze(filtered_events) }

      it 'handles zero duration events correctly' do
        expect(subject[:summary][:total_events]).to eq(2)
        expect(subject[:summary][:total_hours]).to eq(0.0)
        expect(subject[:summary]).to have_key(:most_used_color)
        expect(subject[:summary][:most_used_color][:percentage]).to eq(0)
      end

      it_behaves_like 'proper summary structure'
    end

    context 'with same color aggregation' do
      let(:filtered_events) do
        [
          create_timed_event('イベント1', '2', DateTime.new(2025, 1, 1, 9, 0, 0), DateTime.new(2025, 1, 1, 10, 0, 0)),
          create_timed_event('イベント2', '2', DateTime.new(2025, 1, 1, 11, 0, 0), DateTime.new(2025, 1, 1, 12, 0, 0))
        ]
      end

      subject { service.analyze(filtered_events) }

      it 'aggregates events of same color' do
        green_data = subject[:color_breakdown]['緑']
        expect(green_data[:event_count]).to eq(2)
        expect(green_data[:total_hours]).to eq(2.0)
        expect(green_data[:events].size).to eq(2)
      end
    end
  end

  describe 'duration calculation and formatting' do
    where(:case_name, :event_creator, :expected_hours, :expected_format, :color_name) do
      [
        ['30 minutes timed', proc { create_timed_event('30分', '1', DateTime.new(2025, 1, 1, 10, 0, 0), DateTime.new(2025, 1, 1, 10, 30, 0)) }, 0.5, '2025-01-01 10:00', '薄紫'],
        ['90 minutes timed', proc { create_timed_event('ミーティング', '2', DateTime.new(2025, 1, 1, 9, 0, 0), DateTime.new(2025, 1, 1, 10, 30, 0)) }, 1.5, '2025-01-01 09:00', '緑'],
        ['cross midnight', proc { create_timed_event('深夜', '2', DateTime.new(2025, 1, 1, 23, 0, 0), DateTime.new(2025, 1, 2, 1, 0, 0)) }, 2.0, '2025-01-01 23:00', '緑'],
        ['single day all-day', proc { create_all_day_event('休日', '3', '2025-01-01', '2025-01-02') }, 24.0, '2025-01-01 (All-day)', '紫'],
        ['one week all-day', proc { create_all_day_event('休暇', '3', '2025-01-01', '2025-01-08') }, 168.0, '2025-01-01 (All-day)', '紫'],
        ['multi-day all-day', proc { create_all_day_event('研修', '4', '2025-01-01', '2025-01-03') }, 48.0, '2025-01-01 (All-day)', '赤'],
        ['unknown time', proc { create_unknown_time_event('不明', '5') }, 0.0, 'Unknown time', '黄']
      ]
    end

    with_them do
      let(:filtered_events) { [event_creator.call] }
      subject { service.analyze(filtered_events) }

      it 'calculates duration and formats time correctly' do
        color_data = subject[:color_breakdown][color_name]
        expect(color_data[:total_hours]).to eq(expected_hours)

        event_data = color_data[:events].first
        expect(event_data[:start_time]).to eq(expected_format)
      end
    end
  end

  describe 'rounding behavior' do
    where(:case_name, :event_creator, :expected_hours, :breakdown_key) do
      [
        ['decimal rounding', proc { create_timed_event('小数点', '2', DateTime.new(2025, 1, 1, 9, 0, 0), DateTime.new(2025, 1, 1, 11, 7, 30)) }, 2.13, '緑'],
        ['edge case rounding', proc { create_timed_event('18秒', '2', DateTime.new(2025, 1, 1, 9, 0, 0), DateTime.new(2025, 1, 1, 9, 0, 18)) }, 0.01, '緑'],
        ['very short duration', proc { create_timed_event('1秒', '1', DateTime.new(2025, 1, 1, 10, 0, 0), DateTime.new(2025, 1, 1, 10, 0, 1)) }, 0.0, '薄紫']
      ]
    end

    with_them do
      let(:filtered_events) { [event_creator.call] }
      subject { service.analyze(filtered_events) }

      it 'rounds hours correctly' do
        breakdown_data = subject[:color_breakdown][breakdown_key]
        expect(breakdown_data[:total_hours]).to eq(expected_hours)
        expect(subject[:summary][:total_hours]).to eq(expected_hours)
      end
    end
  end

  describe 'edge cases handling' do
    context 'with invalid color ID' do
      let(:filtered_events) { [create_timed_event('無効色', '99', DateTime.new(2025, 1, 1, 10, 0, 0), DateTime.new(2025, 1, 1, 11, 0, 0))] }
      subject { service.analyze(filtered_events) }

      it 'handles invalid color ID gracefully' do
        breakdown_data = subject[:color_breakdown]['不明 (99)']
        expect(breakdown_data[:total_hours]).to eq(1.0)
        expect(subject[:summary][:total_hours]).to eq(1.0)
      end
    end

    context 'with nil color ID' do
      let(:filtered_events) { [create_timed_event('デフォルト', nil, DateTime.new(2025, 1, 1, 10, 0, 0), DateTime.new(2025, 1, 1, 11, 0, 0))] }
      subject { service.analyze(filtered_events) }

      it 'uses default color for nil color_id' do
        breakdown_data = subject[:color_breakdown]['青']
        expect(breakdown_data[:total_hours]).to eq(1.0)
        expect(subject[:summary][:total_hours]).to eq(1.0)
      end
    end
  end

  describe 'nil title handling' do
    let(:filtered_events) { [create_timed_event(nil, '1', DateTime.new(2025, 1, 1, 10, 0, 0), DateTime.new(2025, 1, 1, 11, 0, 0))] }
    subject { service.analyze(filtered_events) }

    it 'assigns default title for nil summary' do
      breakdown_data = subject[:color_breakdown]['薄紫']
      expect(breakdown_data[:total_hours]).to eq(1.0)
      expect(breakdown_data[:events].first[:title]).to eq('（タイトルなし）')
    end
  end

  describe 'percentage calculation' do
    let(:filtered_events) do
      [
        create_timed_event('短時間', '2', DateTime.new(2025, 1, 1, 9, 0, 0), DateTime.new(2025, 1, 1, 11, 0, 0)),    # 2時間
        create_timed_event('長時間', '3', DateTime.new(2025, 1, 1, 13, 0, 0), DateTime.new(2025, 1, 1, 16, 0, 0))    # 3時間
      ]
    end

    subject { service.analyze(filtered_events) }

    it 'calculates percentage correctly' do
      most_used = subject[:summary][:most_used_color]
      expect(most_used[:name]).to eq('紫')
      expect(most_used[:hours]).to eq(3.0)
      expect(most_used[:percentage]).to eq(60.0)
    end
  end

  describe 'complex color aggregation and sorting' do
    let(:filtered_events) do
      [
        create_timed_event('緑1', '2', DateTime.new(2025, 1, 1, 10, 0, 0), DateTime.new(2025, 1, 1, 13, 0, 0)),    # 3時間
        create_timed_event('緑2', '2', DateTime.new(2025, 1, 1, 14, 0, 0), DateTime.new(2025, 1, 1, 16, 0, 0)),    # 2時間
        create_timed_event('薄紫', '1', DateTime.new(2025, 1, 1, 17, 0, 0), DateTime.new(2025, 1, 1, 18, 0, 0)),   # 1時間
        create_timed_event('赤', '4', DateTime.new(2025, 1, 1, 19, 0, 0), DateTime.new(2025, 1, 1, 23, 0, 0)),     # 4時間
        create_timed_event('青1', '9', DateTime.new(2025, 1, 1, 10, 0, 0), DateTime.new(2025, 1, 1, 12, 0, 0)),    # 2時間（同一時間）
        create_timed_event('黄', '5', DateTime.new(2025, 1, 1, 14, 0, 0), DateTime.new(2025, 1, 1, 16, 0, 0))      # 2時間（同一時間）
      ]
    end

    subject { service.analyze(filtered_events) }

    it 'sorts colors by total hours descending' do
      color_names = subject[:color_breakdown].keys
      expect(color_names).to eq(['緑', '赤', '青', '黄', '薄紫'])
    end

    it 'aggregates events by color correctly' do
      expect(subject[:color_breakdown]['緑'][:total_hours]).to eq(5.0)
      expect(subject[:color_breakdown]['緑'][:event_count]).to eq(2)
      expect(subject[:color_breakdown]['緑'][:events].length).to eq(2)

      expect(subject[:color_breakdown]['赤'][:total_hours]).to eq(4.0)
      expect(subject[:color_breakdown]['赤'][:event_count]).to eq(1)
    end

    it 'calculates most used color correctly' do
      most_used = subject[:summary][:most_used_color]
      expect(most_used[:name]).to eq('緑')
      expect(most_used[:hours]).to eq(5.0)
      expect(most_used[:percentage]).to eq(35.7) # 5/14 * 100, rounded to 1 decimal
    end

    it 'maintains stable sort for identical hours' do
      color_names = subject[:color_breakdown].keys
      blue_index = color_names.index('青')
      yellow_index = color_names.index('黄')

      expect(blue_index).to be < yellow_index # 青が黄より先に処理される
      expect(subject[:color_breakdown]['青'][:total_hours]).to eq(2.0)
      expect(subject[:color_breakdown]['黄'][:total_hours]).to eq(2.0)
    end
  end
end
