# frozen_string_literal: true

module Domain
  class EventFilterService
    def apply_filters(events, color_filters, user_email)
      # 参加イベントフィルタリング（ビジネスルール）
      attended_events = events.select { |event| event.attended_by?(user_email) }

      # 色によるフィルタリング（ビジネスルール）
      filter_by_colors(attended_events, color_filters)
    end

    private

    def filter_by_colors(events, color_filters)
      return events unless color_filters

      # 色による包含/除外ロジック（ドメインルール）
      if color_filters[:include_colors]
        events.select { |event| color_filters[:include_colors].include?(event.color_id) }
      elsif color_filters[:exclude_colors]
        events.reject { |event| color_filters[:exclude_colors].include?(event.color_id) }
      else
        events
      end
    end
  end
end
