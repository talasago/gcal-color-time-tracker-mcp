module InterfaceAdapters
  module Presenters
    class CalendarAnalysisPresenter
      def self.format_text(result, include_colors: nil, exclude_colors: nil)
        output = ["📊 Color-Based Time Analysis Results:", "=" * 50, ""]

        if include_colors || exclude_colors
          output << "🎨 Color Filter Settings:"
          output << "  Include colors: #{include_colors&.join(', ') || 'All colors'}"
          output << "  Exclude colors: #{exclude_colors&.join(', ') || 'None'}"
          output << ""
        end

        result[:color_breakdown].each do |color_name, data|
          hours = data[:total_hours]
          minutes = ((hours % 1) * 60).round

          output << "🎨 #{color_name}:"
          output << "  Time: #{hours.to_i} hours #{minutes} minutes"
          output << "  Event count: #{data[:event_count]} events"

          if data[:events].any?
            main_events = data[:events].first(3).map { |e| e[:title] }.join(", ")
            output << "  Main events: #{main_events}"
          end
          output << ""
        end

        summary = result[:summary]
        output << "📈 Summary:"
        output << "  Total time: #{summary[:total_hours]} hours"
        output << "  Total events: #{summary[:total_events]} events"

        if summary[:most_used_color]
          most_used = summary[:most_used_color]
          output << "  Most used color: #{most_used[:name]} (#{most_used[:hours]} hours, #{most_used[:percentage]}%)"
        end

        output.join("\n")
      end
    end
  end
end