# frozen_string_literal: true

require_relative '../entities/color_constants'
require_relative '../../loggable'


module Domain
  class TimeAnalysisService
    include CalendarColorMCP::Loggable

    def analyze(filtered_events)
      # filtered_eventsは Domain::EventFilterService により
      # 事前にフィルタリング済みのイベント配列
      color_breakdown = analyze_by_color(filtered_events)
      summary = generate_summary(color_breakdown, filtered_events.count)

      {
        color_breakdown: color_breakdown,
        summary: summary
      }
    end

    private

    def analyze_by_color(events)
      color_data = {}

      events.each do |event|
        color_id = event.color_id&.to_i || Domain::ColorConstants.default_color_id
        color_name = Domain::ColorConstants.color_name(color_id) || "不明 (#{color_id})"

        color_data[color_name] ||= {
          total_hours: 0.0,
          event_count: 0,
          events: []
        }

        duration = event.duration_hours
        color_data[color_name][:total_hours] += duration
        color_data[color_name][:event_count] += 1
        color_data[color_name][:events] << {
          title: event.summary || '（タイトルなし）',
          duration: duration,
          start_time: format_event_time(event)
        }
      end

      # 時間順でソート
      color_data = color_data.sort_by { |_, data| -data[:total_hours] }.to_h

      # 時間を四捨五入
      color_data.each do |_, data|
        data[:total_hours] = data[:total_hours].round(2)
      end

      color_data
    end


    def format_event_time(event)
      return 'Unknown time' if event.start_time.nil?

      if event.start_time.is_a?(DateTime) || event.start_time.is_a?(Time)
        # 時刻が00:00:00の場合は終日イベントとして扱う
        if event.start_time.hour == 0 && event.start_time.min == 0 && event.start_time.sec == 0
          "#{event.start_time.strftime('%Y-%m-%d')} (All-day)"
        else
          event.start_time.strftime('%Y-%m-%d %H:%M')
        end
      else
        'Unknown time'
      end
    end

    def generate_summary(color_breakdown, event_count)
      total_hours = color_breakdown.values.sum { |data| data[:total_hours] }

      most_used_color = color_breakdown.first if color_breakdown.any?

      summary = {
        total_hours: total_hours.round(2),
        total_events: event_count
      }

      if most_used_color
        color_name, color_data = most_used_color
        percentage = total_hours > 0 ? ((color_data[:total_hours] / total_hours) * 100).round(1) : 0

        summary[:most_used_color] = {
          name: color_name,
          hours: color_data[:total_hours],
          percentage: percentage
        }
      end

      summary
    end
  end
end
