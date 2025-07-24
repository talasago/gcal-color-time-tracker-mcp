require 'date'

module CalendarColorMCP
  class TimeAnalyzer
    COLOR_NAMES = {
      1 => '薄紫', 2 => '緑', 3 => '紫', 4 => '赤', 5 => '黄',
      6 => 'オレンジ', 7 => '水色', 8 => '灰色', 9 => '青', 
      10 => '濃い緑', 11 => '濃い赤'
    }.freeze

    def analyze(events, start_date, end_date)
      color_breakdown = analyze_by_color(events)
      summary = generate_summary(color_breakdown, events.count)
      
      {
        color_breakdown: color_breakdown,
        summary: summary
      }
    end

    private

    def analyze_by_color(events)
      color_data = {}
      
      events.each do |event|
        color_id = event.color_id&.to_i || 9  # デフォルトは青
        color_name = COLOR_NAMES[color_id] || "不明 (#{color_id})"
        
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
      if event.start.date_time && event.end.date_time
        # 通常のイベント（時刻指定）
        duration_seconds = event.end.date_time - event.start.date_time
        duration_seconds / 3600.0  # 時間に変換
      elsif event.start.date && event.end.date
        # 終日イベント
        start_date = Date.parse(event.start.date)
        end_date = Date.parse(event.end.date)
        (end_date - start_date).to_i * 24.0
      else
        # その他（時間不明）
        0.0
      end
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

    def generate_summary(color_breakdown, total_events)
      total_hours = color_breakdown.values.sum { |data| data[:total_hours] }
      
      most_used_color = color_breakdown.first if color_breakdown.any?
      
      summary = {
        total_hours: total_hours.round(2),
        total_events: total_events
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