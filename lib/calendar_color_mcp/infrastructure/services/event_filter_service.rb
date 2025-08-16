module Infrastructure
  class EventFilterService
    def filter_attended_events(events, user_email)
      events.select { |event| attended_event?(event, user_email) }
    end

    private

    def attended_event?(event, user_email)
      # 主催者の場合は自動的に参加とみなす
      return true if event.organizer&.self

      # 参加者情報がない場合（プライベートイベント）は参加とみなす
      return true if event.attendees.nil? || event.attendees.empty?

      # 参加者リストから自分の参加状況を確認
      user_attendee = event.attendees.find { |attendee|
        attendee.email == user_email || attendee.self
      }

      if user_attendee
        # 参加承認している場合のみ true
        user_attendee.response_status == 'accepted'
      else
        # 参加者リストにいない場合は参加とみなす（プライベートイベントなど）
        true
      end
    end

    def get_attendance_status(event, user_email)
      if event.organizer&.self
        "Organizer"
      elsif event.attendees.nil? || event.attendees.empty?
        "Private event"
      else
        user_attendee = event.attendees.find { |attendee|
          attendee.email == user_email || attendee.self
        }

        if user_attendee
          case user_attendee.response_status
          when 'accepted' then 'Accepted'
          when 'declined' then 'Declined'
          when 'tentative' then 'Tentative'
          when 'needsAction' then 'Needs action'
          else user_attendee.response_status || 'Unknown'
          end
        else
          "No attendee list"
        end
      end
    end
  end
end