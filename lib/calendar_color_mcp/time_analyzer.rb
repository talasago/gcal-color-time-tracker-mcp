require 'date'
require_relative 'color_constants'

module CalendarColorMCP
  class TimeAnalyzer

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
      if ENV['DEBUG']
        STDERR.puts "\n--- 時間計算デバッグ ---"
        STDERR.puts "イベント: #{event.summary}"
        STDERR.puts "start.date_time: #{event.start.date_time.inspect}"
        STDERR.puts "start.date: #{event.start.date.inspect}"
        STDERR.puts "end.date_time: #{event.end.date_time.inspect}"
        STDERR.puts "end.date: #{event.end.date.inspect}"
      end

      duration = if event.start.date_time && event.end.date_time
        # 通常のイベント（時刻指定）
        if ENV['DEBUG']
          STDERR.puts "判定: 時刻指定イベント"
        end
        duration_seconds = event.end.date_time - event.start.date_time
        # Rationalを秒数に変換（1日 = 86400秒）
        duration_seconds_float = duration_seconds * 86400
        calculated_duration = duration_seconds_float / 3600.0
        if ENV['DEBUG']
          STDERR.puts "duration_seconds (Rational): #{duration_seconds}"
          STDERR.puts "duration_seconds_float: #{duration_seconds_float}秒"
          STDERR.puts "calculated_duration: #{calculated_duration}時間"
        end
        calculated_duration
      elsif event.start.date && event.end.date
        # 終日イベント
        if ENV['DEBUG']
          STDERR.puts "判定: 終日イベント"
        end
        start_date = Date.parse(event.start.date)
        end_date = Date.parse(event.end.date)
        calculated_duration = (end_date - start_date).to_i * 24.0
        if ENV['DEBUG']
          STDERR.puts "start_date: #{start_date}"
          STDERR.puts "end_date: #{end_date}"
          STDERR.puts "日数: #{(end_date - start_date).to_i}"
          STDERR.puts "calculated_duration: #{calculated_duration}時間"
        end
        calculated_duration
      else
        # その他（時間不明）
        if ENV['DEBUG']
          STDERR.puts "判定: 時間不明"
        end
        0.0
      end

      if ENV['DEBUG']
        STDERR.puts "最終duration: #{duration}時間"
        STDERR.puts "---"
      end

      duration
    end

    def format_event_time(event)
      if event.start.date_time
        event.start.date_time.strftime('%Y-%m-%d %H:%M')
      elsif event.start.date
        "#{event.start.date}（終日）"
      else
        '時間不明'
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
