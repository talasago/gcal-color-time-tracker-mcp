require 'spec_helper'
require 'date'
require_relative '../../../lib/calendar_color_mcp/domain/services/time_analysis_service'
require_relative '../../../lib/calendar_color_mcp/domain/entities/color_constants'
require_relative '../../support/event_factory'

describe Domain::TimeAnalysisService do
  subject(:service) { described_class.new }

  describe '#analyze' do
    context 'with comprehensive mixed events' do
      let(:filtered_events) do
        [
          EventFactory.timed_event(summary: 'ミーティング', color_id: EventFactory::GREEN, start_time: DateTime.new(2025, 1, 1, 9, 0, 0), duration_hours: 1.5),
          EventFactory.all_day_event(summary: '会議', color_id: EventFactory::PURPLE, start_date: '2025-01-01', duration_days: 1),
          EventFactory.all_day_event(summary: '研修', color_id: EventFactory::RED, start_date: '2025-01-01', duration_days: 2),
          EventFactory.unknown_time_event(summary: '不明イベント', color_id: EventFactory::YELLOW),
          EventFactory.timed_event(summary: nil, color_id: EventFactory::ORANGE, start_time: DateTime.new(2025, 1, 1, 14, 0, 0), duration_hours: 1.0),
          EventFactory.timed_event(summary: 'デフォルト色イベント', color_id: nil, start_time: DateTime.new(2025, 1, 1, 16, 0, 0), duration_hours: 1.0),
          EventFactory.timed_event(summary: 'Sage2', color_id: EventFactory::GREEN, duration_hours: 2.0),
          EventFactory.timed_event(summary: 'Sage3', color_id: EventFactory::GREEN, duration_hours: 1.5)
        ]
      end

      subject { service.analyze(filtered_events) }

      it 'categorizes, aggregates and sorts events by color correctly' do
        color_breakdown = subject[:color_breakdown]

        # 色別分類と集計
        expect(color_breakdown['Sage']).to include(total_hours: 5.0, event_count: 3)
        expect(color_breakdown['Grape']).to include(total_hours: 24.0, event_count: 1)
        expect(color_breakdown['Flamingo']).to include(total_hours: 48.0, event_count: 1)
        expect(color_breakdown['Tangerine']).to include(total_hours: 1.0, event_count: 1)
        expect(color_breakdown['Peacock']).to include(total_hours: 1.0, event_count: 1) # デフォルト色
        expect(color_breakdown['Banana']).to include(total_hours: 0.0, event_count: 1) # ゼロ時間

        # 時間降順ソート
        color_names = subject[:color_breakdown].keys
        expect(color_names.first).to eq('Flamingo')
        expect(color_names[1]).to eq('Grape')
        expect(color_names[2]).to eq('Sage')
        expect(color_names.last).to eq('Banana')
      end

      it 'generates accurate summary with most used color calculation' do
        summary = subject[:summary]
        
        expect(summary[:total_events]).to eq(8)
        expect(summary[:total_hours]).to eq(79.0)
        expect(summary[:most_used_color][:name]).to eq('Flamingo')
        expect(summary[:most_used_color][:hours]).to eq(48.0)
        expect(summary[:most_used_color][:percentage]).to eq(60.8) # 48/79 * 100, rounded
      end

      it 'handles nil summaries and color IDs correctly' do
        # nil title handling
        orange_events = subject[:color_breakdown]['Tangerine'][:events]
        expect(orange_events.first[:title]).to eq('（タイトルなし）')

        # nil color_id → デフォルト色
        expect(subject[:color_breakdown]).to have_key('Peacock')
      end

      it 'formats event times correctly for different types' do
        color_breakdown = subject[:color_breakdown]
        
        # Timed event formatting
        green_event = color_breakdown['Sage'][:events].find { |e| e[:title] == 'ミーティング' }
        expect(green_event[:start_time]).to eq('2025-01-01 09:00')
        
        # All-day event formatting
        purple_event = color_breakdown['Grape'][:events].first
        expect(purple_event[:start_time]).to eq('2025-01-01 (All-day)')
        
        # Unknown time event formatting
        yellow_event = color_breakdown['Banana'][:events].first
        expect(yellow_event[:start_time]).to eq('Unknown time')
      end

      it 'correctly distinguishes midnight meetings from all-day events' do
        filtered_events = [
          # Midnight meeting (should not be treated as all-day)
          EventFactory.timed_event(
            summary: '深夜ミーティング',
            color_id: EventFactory::BLUE,
            start_time: DateTime.new(2025, 1, 1, 0, 0, 0),
            duration_hours: 1.0
          ),
          # True all-day event
          EventFactory.all_day_event(
            summary: '終日会議',
            color_id: EventFactory::GREEN,
            start_date: '2025-01-01'
          )
        ]

        result = service.analyze(filtered_events)
        
        # Midnight meeting should be formatted with time
        blue_event = result[:color_breakdown]['Peacock'][:events].first
        expect(blue_event[:title]).to eq('深夜ミーティング')
        expect(blue_event[:start_time]).to eq('2025-01-01 00:00')
        
        # All-day event should be formatted as all-day
        green_event = result[:color_breakdown]['Sage'][:events].first
        expect(green_event[:title]).to eq('終日会議')
        expect(green_event[:start_time]).to eq('2025-01-01 (All-day)')
      end
    end

    context 'with decimal precision requirements' do
      it 'rounds accumulated hours correctly' do
        filtered_events = [
          # 31分のイベント（0.516666...時間 → 0.52時間に丸め）
          EventFactory.timed_event(
            summary: '31分会議', 
            color_id: EventFactory::GREEN,
            start_time: DateTime.new(2025, 1, 1, 9, 0, 0),
            duration_hours: 31.0/60  # 実際の31分
          ),
          # 25分のレビュー
          EventFactory.timed_event(
            summary: '25分レビュー',
            color_id: EventFactory::GREEN, 
            start_time: DateTime.new(2025, 1, 1, 10, 0, 0),
            duration_hours: 25.0/60  # 実際の25分
          )
        ]
        
        result = service.analyze(filtered_events)
        
        # 累積時間の正確な丸め処理を検証
        expected_total = (31.0/60 + 25.0/60).round(2)  # 0.93時間
        expect(result[:color_breakdown]['Sage'][:total_hours]).to eq(expected_total)
        expect(result[:summary][:total_hours]).to eq(expected_total)
      end

      it 'handles edge rounding cases correctly' do
        filtered_events = [
          # 0.125時間（7.5分）→ 0.13に丸め
          EventFactory.timed_event(summary: '7.5分', color_id: EventFactory::GREEN, duration_hours: 0.125),
          # 0.004時間（14.4秒）→ 0.00に丸め  
          EventFactory.timed_event(summary: '極短', color_id: EventFactory::BLUE, duration_hours: 0.004)
        ]
        
        result = service.analyze(filtered_events)
        
        expect(result[:color_breakdown]['Sage'][:total_hours]).to eq(0.13)
        expect(result[:color_breakdown]['Peacock'][:total_hours]).to eq(0.00)
      end
    end

    context 'with edge cases' do
      it 'handles invalid color IDs gracefully' do
        filtered_events = [EventFactory.timed_event(summary: '無効色', color_id: '99', duration_hours: 1.0)]
        result = service.analyze(filtered_events)
        
        breakdown_data = result[:color_breakdown]['不明 (99)']
        expect(breakdown_data[:total_hours]).to eq(1.0)
        expect(result[:summary][:total_hours]).to eq(1.0)
      end

      it 'handles all zero duration events correctly' do
        filtered_events = [
          EventFactory.unknown_time_event(summary: '不明1', color_id: EventFactory::LAVENDER),
          EventFactory.unknown_time_event(summary: '不明2', color_id: EventFactory::GREEN)
        ]
        result = service.analyze(filtered_events)

        expect(result[:summary][:total_events]).to eq(2)
        expect(result[:summary][:total_hours]).to eq(0.0)
        expect(result[:summary]).to have_key(:most_used_color)
        expect(result[:summary][:most_used_color][:percentage]).to eq(0)
      end
    end

    context 'with boundary conditions' do
      it 'processes empty event list correctly' do
        filtered_events = []
        result = service.analyze(filtered_events)

        expect(result[:summary][:total_events]).to eq(0)
        expect(result[:summary][:total_hours]).to eq(0)
        expect(result[:summary]).not_to have_key(:most_used_color)
        expect(result[:color_breakdown]).to be_empty
      end

      it 'processes single event correctly' do
        filtered_events = [EventFactory.timed_event(summary: 'ミーティング', color_id: EventFactory::GREEN, duration_hours: 1.5)]
        result = service.analyze(filtered_events)

        expect(result[:summary][:total_events]).to eq(1)
        expect(result[:summary][:total_hours]).to eq(1.5)
        expect(result[:summary]).to have_key(:most_used_color)
        expect(result[:summary][:most_used_color][:percentage]).to eq(100.0)
      end
    end
  end
end