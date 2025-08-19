require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/domain/entities/calendar_event'
require_relative '../../../lib/calendar_color_mcp/domain/errors'
require_relative '../../../lib/calendar_color_mcp/domain/entities/color_constants'

describe Domain::CalendarEvent do
  let(:summary) { 'Test Event' }
  let(:start_time) { Time.new(2025, 1, 1, 9, 0, 0) }
  let(:end_time) { Time.new(2025, 1, 1, 10, 0, 0) }
  let(:color_id) { 2 }
  let(:attendees) { [] }
  let(:organizer) { nil }

  subject(:event) do
    described_class.new(
      summary: summary,
      start_time: start_time,
      end_time: end_time,
      color_id: color_id,
      attendees: attendees,
      organizer: organizer
    )
  end

  describe '#duration_hours' do
    context 'with Time objects (legacy)' do
      context 'with valid start and end times' do
        it 'should calculate duration in hours' do
          expect(event.duration_hours).to eq(1.0)
        end
      end

      context 'with different duration' do
        let(:end_time) { Time.new(2025, 1, 1, 11, 30, 0) }

        it 'should calculate correct duration' do
          expect(event.duration_hours).to eq(2.5)
        end
      end

      context 'with fractional duration' do
        let(:end_time) { Time.new(2025, 1, 1, 9, 37, 30) }

        it 'should calculate precise fractional hours' do
          # 37分30秒 = 37.5分 = 0.625時間
          expect(event.duration_hours).to be_within(0.001).of(0.625)
        end
      end

      context 'with complex fractional duration' do
        let(:start_time) { Time.new(2025, 1, 1, 9, 15, 45) }
        let(:end_time) { Time.new(2025, 1, 1, 11, 48, 20) }

        it 'should handle complex time calculations' do
          # 2時間32分35秒 = 2.542777... 時間
          expect(event.duration_hours).to be_within(0.001).of(2.5427777777777777)
        end
      end

      context 'when start_time is nil' do
        let(:start_time) { nil }

        it 'should return 0' do
          expect(event.duration_hours).to eq(0)
        end
      end

      context 'when end_time is nil' do
        let(:end_time) { nil }

        it 'should return 0' do
          expect(event.duration_hours).to eq(0)
        end
      end
    end

    context 'with Google Calendar API format (date_time based)' do
      context 'with timed events (DateTime objects)' do
        let(:start_time) { double('start', date_time: DateTime.new(2025, 1, 1, 9, 0, 0), date: nil) }
        let(:end_time) { double('end', date_time: DateTime.new(2025, 1, 1, 10, 30, 0), date: nil) }

        it 'should calculate correct duration for 1.5 hours' do
          expect(event.duration_hours).to eq(1.5)
        end
      end

      context 'with cross-midnight timed events' do
        let(:start_time) { double('start', date_time: DateTime.new(2025, 1, 1, 23, 0, 0), date: nil) }
        let(:end_time) { double('end', date_time: DateTime.new(2025, 1, 2, 1, 0, 0), date: nil) }

        it 'should calculate correct duration for 2 hours crossing midnight' do
          expect(event.duration_hours).to eq(2.0)
        end
      end

      context 'with fractional timed events' do
        let(:start_time) { double('start', date_time: DateTime.new(2025, 1, 1, 9, 0, 0), date: nil) }
        let(:end_time) { double('end', date_time: DateTime.new(2025, 1, 1, 11, 7, 30), date: nil) }

        it 'should calculate correct duration and round to 2 decimals' do
          expect(event.duration_hours).to be_within(0.01).of(2.13)
        end
      end
    end

    context 'with Google Calendar API format (all-day events)' do
      context 'with single day all-day event' do
        let(:start_time) { double('start', date_time: nil, date: '2025-01-01') }
        let(:end_time) { double('end', date_time: nil, date: '2025-01-02') }

        it 'should calculate 24 hours for single day' do
          expect(event.duration_hours).to eq(24.0)
        end
      end

      context 'with multi-day all-day event' do
        let(:start_time) { double('start', date_time: nil, date: '2025-01-01') }
        let(:end_time) { double('end', date_time: nil, date: '2025-01-03') }

        it 'should calculate 48 hours for 2 days' do
          expect(event.duration_hours).to eq(48.0)
        end
      end

      context 'with one week all-day event' do
        let(:start_time) { double('start', date_time: nil, date: '2025-01-01') }
        let(:end_time) { double('end', date_time: nil, date: '2025-01-08') }

        it 'should calculate 168 hours for 7 days' do
          expect(event.duration_hours).to eq(168.0)
        end
      end
    end

    context 'with unknown time format' do
      context 'when both date_time and date are nil' do
        let(:start_time) { double('start', date_time: nil, date: nil) }
        let(:end_time) { double('end', date_time: nil, date: nil) }

        it 'should return 0 for unknown time' do
          expect(event.duration_hours).to eq(0.0)
        end
      end

      context 'when start_time has no time info' do
        let(:start_time) { nil }
        let(:end_time) { double('end', date_time: DateTime.new(2025, 1, 1, 10, 0, 0), date: nil) }

        it 'should return 0 for missing start time' do
          expect(event.duration_hours).to eq(0.0)
        end
      end

      context 'when end_time has no time info' do
        let(:start_time) { double('start', date_time: DateTime.new(2025, 1, 1, 9, 0, 0), date: nil) }
        let(:end_time) { nil }

        it 'should return 0 for missing end time' do
          expect(event.duration_hours).to eq(0.0)
        end
      end
    end
  end

  describe '#attended_by?' do
    let(:user_email) { 'test@example.com' }

    context 'when user is organizer' do
      let(:organizer) { double('organizer', self?: true) }

      it 'should return true' do
        expect(event.attended_by?(user_email)).to be true
      end
    end

    context 'when event is private (no attendees)' do
      # TODO: Googleカレンダーの仕様上、参加者がいるイベントは基本的にプライベートではないらしい。ほんとか？
      let(:attendees) { nil }
      let(:organizer) { double('organizer', self?: false) }

      it 'should return true' do
        expect(event.attended_by?(user_email)).to be true
      end
    end

    context 'when event is private (empty attendees)' do
      # TODO: Googleカレンダーの仕様上、参加者がいるイベントは基本的にプライベートではないらしい。ほんとか？
      let(:attendees) { [] }
      let(:organizer) { double('organizer', self?: false) }

      it 'should return true' do
        expect(event.attended_by?(user_email)).to be true
      end
    end

    context 'with attendees' do
      let(:organizer) { double('organizer', self?: false) }

      context 'when user accepted invitation' do
        let(:attendees) do
          [
            double('attendee1', email: user_email, self?: true, accepted?: true),
            double('attendee2', email: 'other@example.com', self?: false, accepted?: true)
          ]
        end

        it 'should return true' do
          expect(event.attended_by?(user_email)).to be true
        end
      end

      context 'when user declined invitation' do
        let(:attendees) do
          [
            double('attendee', email: user_email, self?: true, accepted?: false)
          ]
        end

        it 'should return false' do
          expect(event.attended_by?(user_email)).to be false
        end
      end

      context 'when user is not in attendees list' do
        let(:attendees) do
          [
            double('attendee', email: 'other@example.com', self?: false, accepted?: true)
          ]
        end

        it 'should return false' do
          expect(event.attended_by?(user_email)).to be false
        end
      end

      context 'when attendee has self flag but different email' do
        let(:attendees) do
          [
            double('attendee', email: 'different@example.com', self?: true, accepted?: true)
          ]
        end

        it 'should return true' do
          expect(event.attended_by?(user_email)).to be true
        end
      end
    end
  end

  describe '#color_name' do
    context 'with valid color_id' do
      it 'should return corresponding color name' do
        expect(event.color_name).to eq('緑')
      end
    end

    context 'with invalid color_id' do
      let(:color_id) { 99 }

      it 'should return default color name' do
        expect(event.color_name).to eq(Domain::ColorConstants::COLOR_NAMES[Domain::ColorConstants::DEFAULT_COLOR_ID])
      end
    end

    context 'with nil color_id' do
      let(:color_id) { nil }

      it 'should return default color name' do
        expect(event.color_name).to eq(Domain::ColorConstants::COLOR_NAMES[Domain::ColorConstants::DEFAULT_COLOR_ID])
      end
    end
  end
end
