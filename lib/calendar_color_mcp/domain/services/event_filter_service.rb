# frozen_string_literal: true

require_relative '../entities/color_constants'

module Domain
  class EventFilterService
    def apply_filters(events, user_email, include_colors: nil, exclude_colors: nil)
      # 参加イベントフィルタリング（ビジネスルール）
      attended_events = events.select { |event| event.attended_by?(user_email) }

      # 色によるフィルタリング（ビジネスルール）
      filter_by_colors(attended_events, include_colors, exclude_colors)
    end
    private

    def filter_by_colors(events, include_colors, exclude_colors)
      return events unless include_colors || exclude_colors

      # 色の正規化（色名 → 色ID変換）
      normalized_include = Domain::ColorConstants.normalize_colors(include_colors) if include_colors
      normalized_exclude = Domain::ColorConstants.normalize_colors(exclude_colors) if exclude_colors

      # 色による包含/除外ロジック（ドメインルール）
      if normalized_include
        events.select { |event| normalized_include.include?(event.color_id) }
      elsif normalized_exclude
        events.reject { |event| normalized_exclude.include?(event.color_id) }
      else
        events
      end
    end
  end
end
