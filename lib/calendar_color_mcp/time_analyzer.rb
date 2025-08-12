require 'date'
require_relative 'color_constants'
require_relative 'loggable'

module CalendarColorMCP
  class TimeAnalyzer
    include Loggable

    def analyze(events, start_date, end_date, color_filter: nil)
      # 色フィルタリングを適用
      filtered_events = color_filter ? color_filter.filter_events(events) : events

      color_breakdown = analyze_by_color(filtered_events)
      summary = generate_summary(color_breakdown, filtered_events.count,
                                 original_count: events.count, color_filter: color_filter)

      {
        color_breakdown: color_breakdown,
        summary: summary
      }
    end

    private

    def analyze_by_color(events)
      color_data = {}

      events.each do |event|
        color_id = event.color_id&.to_i || ColorConstants.default_color_id
        color_name = ColorConstants.color_name(color_id) || "不明 (#{color_id})"

        color_data[color_name] ||= {
          total_hours: 0.0,
          event_count: 0,
          events: []
        }

        duration = calculate_duration(event)
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

    def calculate_duration(event)
      logger.debug "--- Duration Calculation Debug ---"
      logger.debug "Event: #{event.summary}"
      logger.debug "start.date_time: #{event.start.date_time.inspect}"
      logger.debug "start.date: #{event.start.date.inspect}"
      logger.debug "end.date_time: #{event.end.date_time.inspect}"
      logger.debug "end.date: #{event.end.date.inspect}"

      duration = if event.start.date_time && event.end.date_time
        # 通常のイベント（時刻指定）
        logger.debug "Type: Timed event"
        duration_seconds = event.end.date_time - event.start.date_time
        # Rationalを秒数に変換（1日 = 86400秒）
        duration_seconds_float = duration_seconds * 86400
        calculated_duration = duration_seconds_float / 3600.0
        logger.debug "duration_seconds (Rational): #{duration_seconds}"
        logger.debug "duration_seconds_float: #{duration_seconds_float} seconds"
        logger.debug "calculated_duration: #{calculated_duration} hours"
        calculated_duration
      elsif event.start.date && event.end.date
        # 終日イベント
        logger.debug "Type: All-day event"
        start_date = Date.parse(event.start.date)
        end_date = Date.parse(event.end.date)
        calculated_duration = (end_date - start_date).to_i * 24.0
        logger.debug "start_date: #{start_date}"
        logger.debug "end_date: #{end_date}"
        logger.debug "Days: #{(end_date - start_date).to_i}"
        logger.debug "calculated_duration: #{calculated_duration} hours"
        calculated_duration
      else
        # その他（時間不明）
        logger.debug "Type: Unknown time"
        0.0
      end

      logger.debug "Final duration: #{duration} hours"
      logger.debug "---"

      duration
    end

    def format_event_time(event)
      if event.start.date_time
        event.start.date_time.strftime('%Y-%m-%d %H:%M')
      elsif event.start.date
        "#{event.start.date} (All-day)"
      else
        'Unknown time'
      end
    end

    def generate_summary(color_breakdown, total_events, original_count: nil, color_filter: nil)
      total_hours = color_breakdown.values.sum { |data| data[:total_hours] }

      most_used_color = color_breakdown.first if color_breakdown.any?

      summary = {
        total_hours: total_hours.round(2),
        total_events: total_events
      }

      # 色フィルタリングが適用されている場合の追加情報
      if color_filter && original_count
        summary[:original_events] = original_count
        summary[:filtered_events] = total_events
        summary[:excluded_events] = original_count - total_events
      end

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
