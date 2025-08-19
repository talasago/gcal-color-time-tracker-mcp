require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/interface_adapters/presenters/calendar_analysis_presenter'

RSpec.describe InterfaceAdapters::Presenters::CalendarAnalysisPresenter do
  describe '.format_text' do
    let(:result) do
      {
        color_breakdown: {
          "赤" => {
            total_hours: 2.5,
            event_count: 3,
            events: [
              { title: "会議A" },
              { title: "会議B" },
              { title: "会議C" }
            ]
          },
          "青" => {
            total_hours: 1.25,
            event_count: 1,
            events: [
              { title: "個人作業" }
            ]
          }
        },
        summary: {
          total_hours: 3.75,
          total_events: 4,
          most_used_color: {
            name: "赤",
            hours: 2.5,
            percentage: 66.7
          }
        }
      }
    end

    context 'without color filtering' do
      subject { described_class.format_text(result) }

      it 'should return properly formatted string' do
        expect(subject).to include("📊 色別時間集計結果:")
        expect(subject).to include("=" * 50)
        expect(subject).to include("🎨 赤:")
        expect(subject).to include("時間: 2時間30分")
        expect(subject).to include("イベント数: 3件")
        expect(subject).to include("主なイベント: 会議A, 会議B, 会議C")
        expect(subject).to include("🎨 青:")
        expect(subject).to include("時間: 1時間15分")
        expect(subject).to include("イベント数: 1件")
        expect(subject).to include("主なイベント: 個人作業")
        expect(subject).to include("📈 サマリー:")
        expect(subject).to include("総時間: 3.75時間")
        expect(subject).to include("総イベント数: 4件")
        expect(subject).to include("最も使用された色: 赤 (2.5時間、66.7%)")
      end
    end

    context 'with color filtering' do
      subject { described_class.format_text(result, include_colors: ["赤"], exclude_colors: ["青"]) }

      it 'should return string with filtering information' do
        expect(subject).to include("🎨 色フィルタリング設定:")
        expect(subject).to include("含める色: 赤")
        expect(subject).to include("除外する色: 青")
      end
    end

    context 'with partial filtering' do
      subject { described_class.format_text(result, include_colors: ["赤"]) }

      it 'should display only include colors' do
        expect(subject).to include("含める色: 赤")
        expect(subject).to include("除外する色: なし")
      end
    end

    context 'when there are more than 3 events' do
      let(:result_with_many_events) do
        {
          color_breakdown: {
            "赤" => {
              total_hours: 4.0,
              event_count: 5,
              events: [
                { title: "イベント1" },
                { title: "イベント2" },
                { title: "イベント3" },
                { title: "イベント4" },
                { title: "イベント5" }
              ]
            }
          },
          summary: {
            total_hours: 4.0,
            total_events: 5,
            most_used_color: {
              name: "赤",
              hours: 4.0,
              percentage: 100.0
            }
          }
        }
      end

      subject { described_class.format_text(result_with_many_events) }

      it 'should display only the first 3 events' do
        expect(subject).to include("主なイベント: イベント1, イベント2, イベント3")
        expect(subject).not_to include("イベント4")
        expect(subject).not_to include("イベント5")
      end
    end

    context 'when there is no most used color' do
      let(:result_without_most_used) do
        {
          color_breakdown: {
            "赤" => {
              total_hours: 2.0,
              event_count: 1,
              events: [{ title: "会議" }]
            }
          },
          summary: {
            total_hours: 2.0,
            total_events: 1,
            most_used_color: nil
          }
        }
      end

      subject { described_class.format_text(result_without_most_used) }

      it 'should not display most used color information' do
        expect(subject).to include("総時間: 2.0時間")
        expect(subject).to include("総イベント数: 1件")
        expect(subject).not_to include("最も使用された色:")
      end
    end
  end
end