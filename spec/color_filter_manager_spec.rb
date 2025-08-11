require 'spec_helper'
require_relative '../lib/calendar_color_mcp/color_filter_manager'

RSpec.describe CalendarColorMCP::ColorFilterManager do
  def mock_event(color_id, summary = "Test Event")
    double('event', color_id: color_id, summary: summary)
  end

  # FIXME:eventsの型や内容がわからないからこれでいいのかわからない
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

  let(:filter_manager) { described_class.new(**init_params) }

  describe '#filter_events' do
    let(:actual_target_events) do
      case target_events_override
      when :nil_events
        [mock_event(nil)]
      else
        events
      end
    end
    subject { filter_manager.filter_events(actual_target_events) }

    where(:case_name, :init_params, :target_events_override, :expected_length, :expected_color_ids) do
      [
        ['no filters set', {}, nil, 6, ['1', '2', '3', '4', '5', nil]],
        ['include specific colors', { include_colors: [1, 3] }, nil, 2, ['1', '3']],
        ['exclude specific colors', { exclude_colors: [1, 2] }, nil, 4, ['3', '4', '5', nil]],
        ['both include and exclude (exclude prioritized)', { include_colors: [1, 2, 3], exclude_colors: [2] }, nil, 2, ['1', '3']],
        ['include default color with nil events', { include_colors: [9] }, :nil_events, 1, [nil]],
        ['exclude default color with nil events', { exclude_colors: [9] }, :nil_events, 0, []],
        ['include with color names', { include_colors: ['薄紫', '紫'] }, nil, 2, ['1', '3']],
        ['mixed color IDs and names', { include_colors: [1, '紫'] }, nil, 2, ['1', '3']]
      ]
    end

    with_them do
      it 'filters events correctly' do
        expect(subject.length).to eq(expected_length)
        expect(subject.map(&:color_id)).to match_array(expected_color_ids)
      end
    end
  end

  describe '#get_filtering_summary' do
    subject { filter_manager.get_filtering_summary }

    where(:case_name, :init_params, :expected_include_colors, :expected_exclude_colors, :expected_has_filters) do
      [
        ['no filters set', {}, nil, nil, nil],
        ['single include color ID', { include_colors: [1] }, '薄紫(1)', nil, [1]],
        ['multiple include color IDs', { include_colors: [1, 3, 5] }, '薄紫(1), 紫(3), 黄(5)', nil, [1, 3, 5]],
        ['include color names', { include_colors: ['緑', '赤'] }, '緑(2), 赤(4)', nil, [2, 4]],
        ['mixed include colors', { include_colors: [1, '緑', 5] }, '薄紫(1), 緑(2), 黄(5)', nil, [1, 2, 5]],
        ['single exclude color ID', { exclude_colors: [2] }, nil, '緑(2)', [2]],
        ['multiple exclude color IDs', { exclude_colors: [2, 4, 6] }, nil, '緑(2), 赤(4), オレンジ(6)', [2, 4, 6]],
        ['exclude color names', { exclude_colors: ['紫', '青'] }, nil, '紫(3), 青(9)', [3, 9]],
        ['mixed exclude colors', { exclude_colors: [2, '赤', 6] }, nil, '緑(2), 赤(4), オレンジ(6)', [2, 4, 6]],
        ['both include and exclude colors', { include_colors: [1, 3], exclude_colors: [2, 4] }, '薄紫(1), 紫(3)', '緑(2), 赤(4)', [1, 3]]
      ]
    end

    with_them do
      it 'returns correct summary' do
        expect(subject[:include_colors]).to eq(expected_include_colors)
        expect(subject[:exclude_colors]).to eq(expected_exclude_colors)
        expect(subject[:has_filters]).to eq(expected_has_filters)
      end
    end
  end
end
