require 'spec_helper'
require_relative '../lib/calendar_color_mcp/color_filter_manager'

RSpec.describe CalendarColorMCP::ColorFilterManager do
  def mock_event(color_id, summary = "Test Event")
    double('event', color_id: color_id, summary: summary)
  end

  let(:events) do
    [
      mock_event('1'),  # 薄紫
      mock_event('2'),  # 緑
      mock_event('3'),  # 紫
      mock_event('4'),  # 赤
      mock_event('5'),  # 黄
      mock_event(nil),  # デフォルト色（青）
    ]
  end

  describe '#filter_events' do
    context 'フィルターが指定されていない場合' do
      let(:filter_manager) { described_class.new }

      it '全てのイベントを返す' do
        result = filter_manager.filter_events(events)
        expect(result.length).to eq(events.length)
        expect(result).to eq(events)
      end
    end

    context 'include_colorsが指定されている場合' do
      let(:filter_manager) { described_class.new(include_colors: [1, 3]) }

      it '指定された色のイベントのみを返す' do
        result = filter_manager.filter_events(events)
        expect(result.length).to eq(2)
        expect(result.map(&:color_id)).to match_array(['1', '3'])
      end
    end

    context 'exclude_colorsが指定されている場合' do
      let(:filter_manager) { described_class.new(exclude_colors: [1, 2]) }

      it '指定された色以外のイベントを返す' do
        result = filter_manager.filter_events(events)
        expect(result.length).to eq(4)
        expect(result.map(&:color_id)).to match_array(['3', '4', '5', nil])
      end
    end

    context 'includeとexcludeの両方が指定されている場合' do
      let(:filter_manager) { described_class.new(include_colors: [1, 2, 3], exclude_colors: [2]) }

      it 'excludeが優先される' do
        result = filter_manager.filter_events(events)
        expect(result.length).to eq(2)
        expect(result.map(&:color_id)).to match_array(['1', '3'])
      end
    end

    context 'color_idがnilのイベント（デフォルト色）' do
      let(:events_with_nil) { [mock_event(nil)] }

      context 'デフォルト色が含まれる場合' do
        let(:filter_manager) { described_class.new(include_colors: [9]) } # 青（デフォルト色）

        it 'デフォルト色のイベントが含まれる' do
          result = filter_manager.filter_events(events_with_nil)
          expect(result.length).to eq(1)
        end
      end

      context 'デフォルト色が除外される場合' do
        let(:filter_manager) { described_class.new(exclude_colors: [9]) } # 青（デフォルト色）

        it 'デフォルト色のイベントが除外される' do
          result = filter_manager.filter_events(events_with_nil)
          expect(result.length).to eq(0)
        end
      end
    end

    context '色名での指定' do
      let(:filter_manager) { described_class.new(include_colors: ['薄紫', '紫']) }

      it '色名で指定された色のイベントを返す' do
        result = filter_manager.filter_events(events)
        expect(result.length).to eq(2)
        expect(result.map(&:color_id)).to match_array(['1', '3'])
      end
    end

    context '色IDと色名の混在指定' do
      let(:filter_manager) { described_class.new(include_colors: [1, '紫']) }

      it '混在指定で正しくフィルタリングされる' do
        result = filter_manager.filter_events(events)
        expect(result.length).to eq(2)
        expect(result.map(&:color_id)).to match_array(['1', '3'])
      end
    end
  end
end