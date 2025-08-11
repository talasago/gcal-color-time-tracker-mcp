require 'spec_helper'
require_relative '../lib/calendar_color_mcp/time_analyzer'
require_relative '../lib/calendar_color_mcp/color_filter_manager'

# TODO: レビューしてないのでレビューする。リアーキテクチャ時に。

RSpec.describe CalendarColorMCP::TimeAnalyzer do
  let(:analyzer) { described_class.new }
  let(:start_date) { Date.new(2024, 1, 1) }
  let(:end_date) { Date.new(2024, 1, 31) }

  # モックイベント作成ヘルパーメソッド
  # TODO:このような形式が正しいのか確認する必要がる
  def mock_timed_event(summary, color_id, start_time, end_time)
    double('event',
      summary: summary,
      color_id: color_id,
      start: double(
        date_time: start_time,
        date: nil
      ),
      end: double(
        date_time: end_time,
        date: nil
      )
    )
  end

  def mock_all_day_event(summary, color_id, start_date, end_date)
    double('event',
      summary: summary,
      color_id: color_id,
      start: double(
        date_time: nil,
        date: start_date
      ),
      end: double(
        date_time: nil,
        date: end_date
      )
    )
  end

  def mock_no_time_event(summary, color_id)
    double('event',
      summary: summary,
      color_id: color_id,
      start: double(
        date_time: nil,
        date: nil
      ),
      end: double(
        date_time: nil,
        date: nil
      )
    )
  end

  describe '#analyze' do
    subject { analyzer.analyze(events, start_date, end_date, color_filter: color_filter) }

    let(:color_filter) { nil }

    context 'with empty events list' do
      let(:events) { [] }

      it 'returns empty color breakdown and zero summary' do
        result = subject

        expect(result[:color_breakdown]).to eq({})
        expect(result[:summary][:total_hours]).to eq(0.0)
        expect(result[:summary][:total_events]).to eq(0)
        expect(result[:summary][:most_used_color]).to be_nil
      end
    end

    context 'with single timed event' do
      let(:events) do
        [
          mock_timed_event('Meeting', '1', DateTime.new(2024, 1, 15, 10, 0), DateTime.new(2024, 1, 15, 11, 30))
        ]
      end

      it 'correctly calculates duration and color breakdown' do
        result = subject

        expect(result[:color_breakdown]['薄紫'][:total_hours]).to eq(1.5)
        expect(result[:color_breakdown]['薄紫'][:event_count]).to eq(1)
        expect(result[:color_breakdown]['薄紫'][:events].length).to eq(1)

        expect(result[:summary][:total_hours]).to eq(1.5)
        expect(result[:summary][:total_events]).to eq(1)
        expect(result[:summary][:most_used_color][:name]).to eq('薄紫')
      end
    end

    context 'with single all-day event' do
      let(:events) do
        [
          mock_all_day_event('Holiday', '2', '2024-01-15', '2024-01-16')
        ]
      end

      it 'correctly calculates all-day duration' do
        result = subject

        expect(result[:color_breakdown]['緑'][:total_hours]).to eq(24.0)
        expect(result[:color_breakdown]['緑'][:event_count]).to eq(1)

        expect(result[:summary][:total_hours]).to eq(24.0)
        expect(result[:summary][:total_events]).to eq(1)
      end
    end

    context 'with event without time information' do
      let(:events) do
        [
          mock_no_time_event('Unknown Time Event', '3')
        ]
      end

      it 'assigns zero duration' do
        result = subject

        expect(result[:color_breakdown]['紫'][:total_hours]).to eq(0.0)
        expect(result[:color_breakdown]['紫'][:event_count]).to eq(1)

        expect(result[:summary][:total_hours]).to eq(0.0)
        expect(result[:summary][:total_events]).to eq(1)
      end
    end

    context 'with multiple events of different colors' do
      let(:events) do
        [
          mock_timed_event('Meeting 1', '1', DateTime.new(2024, 1, 15, 10, 0), DateTime.new(2024, 1, 15, 12, 0)),  # 2 hours, 薄紫
          mock_timed_event('Meeting 2', '2', DateTime.new(2024, 1, 16, 14, 0), DateTime.new(2024, 1, 16, 15, 0)),  # 1 hour, 緑
          mock_timed_event('Meeting 3', '1', DateTime.new(2024, 1, 17, 9, 0), DateTime.new(2024, 1, 17, 10, 30))   # 1.5 hours, 薄紫
        ]
      end

      it 'groups events by color and sorts by total hours descending' do
        result = subject

        # 薄紫 (3.5時間) > 緑 (1時間) の順序で並ぶ
        color_names = result[:color_breakdown].keys
        expect(color_names).to eq(['薄紫', '緑'])

        # 薄紫の集計
        expect(result[:color_breakdown]['薄紫'][:total_hours]).to eq(3.5)
        expect(result[:color_breakdown]['薄紫'][:event_count]).to eq(2)
        expect(result[:color_breakdown]['薄紫'][:events].length).to eq(2)

        # 緑の集計
        expect(result[:color_breakdown]['緑'][:total_hours]).to eq(1.0)
        expect(result[:color_breakdown]['緑'][:event_count]).to eq(1)

        # 全体サマリー
        expect(result[:summary][:total_hours]).to eq(4.5)
        expect(result[:summary][:total_events]).to eq(3)
        expect(result[:summary][:most_used_color][:name]).to eq('薄紫')
        expect(result[:summary][:most_used_color][:hours]).to eq(3.5)
        expect(result[:summary][:most_used_color][:percentage]).to eq(77.8)
      end
    end

    context 'with event having nil color_id (default color)' do
      let(:events) do
        [
          mock_timed_event('Default Color Event', nil, DateTime.new(2024, 1, 15, 10, 0), DateTime.new(2024, 1, 15, 11, 0))
        ]
      end

      it 'assigns default color (青)' do
        result = subject

        expect(result[:color_breakdown]).to have_key('青')
        expect(result[:color_breakdown]['青'][:total_hours]).to eq(1.0)
        expect(result[:color_breakdown]['青'][:event_count]).to eq(1)
      end
    end

    context 'with event having nil summary' do
      let(:events) do
        [
          mock_timed_event(nil, '1', DateTime.new(2024, 1, 15, 10, 0), DateTime.new(2024, 1, 15, 11, 0))
        ]
      end

      it 'assigns default title' do
        result = subject
        event_info = result[:color_breakdown]['薄紫'][:events][0]

        expect(event_info[:title]).to eq('（タイトルなし）')
      end
    end

    context 'with color filter applied' do
      let(:color_filter) { CalendarColorMCP::ColorFilterManager.new(include_colors: [1]) }
      let(:events) do
        [
          mock_timed_event('Meeting 1', '1', DateTime.new(2024, 1, 15, 10, 0), DateTime.new(2024, 1, 15, 11, 0)),  # 薄紫, included
          mock_timed_event('Meeting 2', '2', DateTime.new(2024, 1, 16, 14, 0), DateTime.new(2024, 1, 16, 15, 0))   # 緑, excluded
        ]
      end

      it 'includes filter summary information' do
        result = subject

        expect(result[:color_breakdown]).to have_key('薄紫')
        expect(result[:color_breakdown]).not_to have_key('緑')

        expect(result[:summary][:original_events]).to eq(2)
        expect(result[:summary][:filtered_events]).to eq(1)
        expect(result[:summary][:excluded_events]).to eq(1)
      end
    end


    context 'time calculation patterns' do
      where(:case_name, :event_creator, :expected_hours) do
        [
          # 時刻指定イベント
          ['30 minutes timed event',
           proc { mock_timed_event('Short Meeting', '1', DateTime.new(2024, 1, 15, 10, 0), DateTime.new(2024, 1, 15, 10, 30)) },
           0.5],
          ['1 hour timed event',
           proc { mock_timed_event('Meeting', '1', DateTime.new(2024, 1, 15, 10, 0), DateTime.new(2024, 1, 15, 11, 0)) },
           1.0],
          ['2.5 hours timed event',
           proc { mock_timed_event('Long Meeting', '1', DateTime.new(2024, 1, 15, 10, 0), DateTime.new(2024, 1, 15, 12, 30)) },
           2.5],
          ['cross midnight event',
           proc { mock_timed_event('Night Meeting', '1', DateTime.new(2024, 1, 15, 23, 0), DateTime.new(2024, 1, 16, 1, 0)) },
           2.0],

          # 終日イベント
          ['single day all-day event',
           proc { mock_all_day_event('Holiday', '2', '2024-01-15', '2024-01-16') },
           24.0],
          ['two days all-day event',
           proc { mock_all_day_event('Long Holiday', '2', '2024-01-15', '2024-01-17') },
           48.0],
          ['one week all-day event',
           proc { mock_all_day_event('Vacation', '2', '2024-01-15', '2024-01-22') },
           168.0],

          # 時間不明イベント
          ['no time information event',
           proc { mock_no_time_event('Unknown', '3') },
           0.0]
        ]
      end

      with_them do
        let(:events) { [event_creator.call] }

        it 'calculates duration correctly' do
          result = analyzer.analyze(events, start_date, end_date)
          color_name = result[:color_breakdown].keys.first

          expect(result[:color_breakdown][color_name][:total_hours]).to eq(expected_hours)
          expect(result[:summary][:total_hours]).to eq(expected_hours)
        end
      end
    end

    context 'color aggregation and sorting' do
      context 'with events of different colors and durations' do
        let(:events) do
          [
            # 緑: 5時間 (3 + 2)
            mock_timed_event('Green Event 1', '2', DateTime.new(2024, 1, 15, 10, 0), DateTime.new(2024, 1, 15, 13, 0)),  # 3 hours
            mock_timed_event('Green Event 2', '2', DateTime.new(2024, 1, 16, 14, 0), DateTime.new(2024, 1, 16, 16, 0)),  # 2 hours

            # 薄紫: 1時間
            mock_timed_event('Purple Event', '1', DateTime.new(2024, 1, 17, 9, 0), DateTime.new(2024, 1, 17, 10, 0)),   # 1 hour

            # 赤: 4時間
            mock_timed_event('Red Event', '4', DateTime.new(2024, 1, 18, 11, 0), DateTime.new(2024, 1, 18, 15, 0))     # 4 hours
          ]
        end

        it 'sorts colors by total hours descending' do
          result = analyzer.analyze(events, start_date, end_date)
          color_names = result[:color_breakdown].keys

          # 緑(5時間) > 赤(4時間) > 薄紫(1時間) の順序
          expect(color_names).to eq(['緑', '赤', '薄紫'])
        end

        it 'aggregates events by color correctly' do
          result = analyzer.analyze(events, start_date, end_date)

          # 緑の集計
          expect(result[:color_breakdown]['緑'][:total_hours]).to eq(5.0)
          expect(result[:color_breakdown]['緑'][:event_count]).to eq(2)
          expect(result[:color_breakdown]['緑'][:events].length).to eq(2)

          # 赤の集計
          expect(result[:color_breakdown]['赤'][:total_hours]).to eq(4.0)
          expect(result[:color_breakdown]['赤'][:event_count]).to eq(1)
          expect(result[:color_breakdown]['赤'][:events].length).to eq(1)

          # 薄紫の集計
          expect(result[:color_breakdown]['薄紫'][:total_hours]).to eq(1.0)
          expect(result[:color_breakdown]['薄紫'][:event_count]).to eq(1)
          expect(result[:color_breakdown]['薄紫'][:events].length).to eq(1)
        end

        it 'calculates most used color correctly' do
          result = analyzer.analyze(events, start_date, end_date)

          expect(result[:summary][:most_used_color][:name]).to eq('緑')
          expect(result[:summary][:most_used_color][:hours]).to eq(5.0)
          expect(result[:summary][:most_used_color][:percentage]).to eq(50.0)  # 5/10 * 100
        end

        it 'rounds total hours to 2 decimal places' do
          result = analyzer.analyze(events, start_date, end_date)

          result[:color_breakdown].each do |_, color_data|
            expect(color_data[:total_hours]).to be_a(Numeric)
            expect((color_data[:total_hours] * 100).round).to eq((color_data[:total_hours] * 100).to_i)
          end

          expect(result[:summary][:total_hours]).to be_a(Numeric)
          expect((result[:summary][:total_hours] * 100).round).to eq((result[:summary][:total_hours] * 100).to_i)
        end
      end

      context 'with events having identical total hours' do
        let(:events) do
          [
            mock_timed_event('Blue Event', '9', DateTime.new(2024, 1, 15, 10, 0), DateTime.new(2024, 1, 15, 12, 0)),  # 2 hours
            mock_timed_event('Green Event', '2', DateTime.new(2024, 1, 16, 14, 0), DateTime.new(2024, 1, 16, 16, 0))  # 2 hours
          ]
        end

        it 'maintains stable sort order' do
          result = subject
          color_names = result[:color_breakdown].keys

          # 同じ時間の場合、最初に処理されたものが先に来る
          expect(color_names.length).to eq(2)
          expect(color_names).to include('青', '緑')
        end
      end

      context 'with mixed event types (timed and all-day)' do
        let(:events) do
          [
            mock_all_day_event('All Day Event', '2', '2024-01-15', '2024-01-16'),                                        # 24 hours, 緑
            mock_timed_event('Timed Event', '1', DateTime.new(2024, 1, 16, 10, 0), DateTime.new(2024, 1, 16, 11, 0))   # 1 hour, 薄紫
          ]
        end

        it 'handles mixed event types correctly' do
          result = subject

          expect(result[:color_breakdown]['緑'][:total_hours]).to eq(24.0)
          expect(result[:color_breakdown]['薄紫'][:total_hours]).to eq(1.0)

          # 緑が上位に来る
          expect(result[:color_breakdown].keys.first).to eq('緑')
          expect(result[:summary][:most_used_color][:name]).to eq('緑')
        end
      end
    end

    context 'edge cases and error handling' do
      context 'with invalid color ID' do
        let(:events) do
          [
            mock_timed_event('Invalid Color Event', '99', DateTime.new(2024, 1, 15, 10, 0), DateTime.new(2024, 1, 15, 11, 0))
          ]
        end

        it 'handles invalid color ID gracefully' do
          result = subject

          expect(result[:color_breakdown]).to have_key('不明 (99)')
          expect(result[:color_breakdown]['不明 (99)'][:total_hours]).to eq(1.0)
        end
      end

      context 'with all zero-duration events' do
        let(:events) do
          [
            mock_no_time_event('Event 1', '1'),
            mock_no_time_event('Event 2', '2')
          ]
        end

        it 'handles zero duration events correctly' do
          result = subject

          expect(result[:summary][:total_hours]).to eq(0.0)
          expect(result[:summary][:total_events]).to eq(2)
          expect(result[:summary][:most_used_color][:percentage]).to eq(0)
        end
      end

      context 'with events having very small durations' do
        let(:events) do
          [
            mock_timed_event('Very Short Event', '1',
              DateTime.new(2024, 1, 15, 10, 0, 0),
              DateTime.new(2024, 1, 15, 10, 0, 1))  # 1 second
          ]
        end

        it 'rounds small durations correctly' do
          result = subject

          # 1秒 = 1/3600時間 = 0.000277... hours, rounds to 0.0
          expect(result[:color_breakdown]['薄紫'][:total_hours]).to eq(0.0)
          expect(result[:summary][:total_hours]).to eq(0.0)
        end
      end
    end
  end
end
