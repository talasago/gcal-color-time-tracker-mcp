require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/domain/services/event_filter_service'
require_relative '../../../lib/calendar_color_mcp/domain/entities/calendar_event'
require_relative '../../support/event_factory'

describe Domain::EventFilterService do
  subject(:service) { described_class.new }

  let(:user_email) { 'test@example.com' }

  let(:organizer_event) do
    event = double('event',
      summary: '主催者イベント',
      organizer: double(self: true),
      attendees: nil
    )
    allow(event).to receive(:attended_by?).and_return(true)
    event
  end

  let(:private_event) do
    event = double('event',
      summary: 'プライベートイベント',
      organizer: double(self: false),
      attendees: nil
    )
    allow(event).to receive(:attended_by?).and_return(true)
    event
  end

  let(:private_event_empty_attendees) do
    event = double('event',
      summary: 'プライベートイベント（空配列）',
      organizer: double(self: false),
      attendees: []
    )
    allow(event).to receive(:attended_by?).and_return(true)
    event
  end

  let(:accepted_event) do
    event = double('event',
      summary: '承認済みイベント',
      organizer: double(self: false),
      attendees: [
        double(email: 'test@example.com', self: true, response_status: 'accepted')
      ]
    )
    allow(event).to receive(:attended_by?).and_return(true)
    event
  end

  let(:declined_event) do
    event = double('event',
      summary: '辞退イベント',
      organizer: double(self: false),
      attendees: [
        double(email: 'test@example.com', self: true, response_status: 'declined')
      ]
    )
    allow(event).to receive(:attended_by?).and_return(false)
    event
  end

  let(:tentative_event) do
    event = double('event',
      summary: '仮承認イベント',
      organizer: double(self: false),
      attendees: [
        double(email: 'test@example.com', self: true, response_status: 'tentative')
      ]
    )
    allow(event).to receive(:attended_by?).and_return(false)
    event
  end

  let(:needs_action_event) do
    event = double('event',
      summary: '未応答イベント',
      organizer: double(self: false),
      attendees: [
        double(email: 'test@example.com', self: true, response_status: 'needsAction')
      ]
    )
    allow(event).to receive(:attended_by?).and_return(false)
    event
  end

  let(:not_invited_event) do
    event = double('event',
      summary: '未招待イベント',
      organizer: double(self: false),
      attendees: [
        double(email: 'other@example.com', self: false, response_status: 'accepted')
      ]
    )
    allow(event).to receive(:attended_by?).and_return(false)
    event
  end

  describe '#apply_filters' do
    let(:all_events) do
      [
        organizer_event,
        private_event,
        private_event_empty_attendees,
        accepted_event,
        declined_event,
        tentative_event,
        needs_action_event,
        not_invited_event
      ]
    end

    context 'when filtering attended events without color filters' do
      it 'should return only attended events' do
        result = service.apply_filters(all_events, user_email)

        expect(result).to contain_exactly(organizer_event, private_event, private_event_empty_attendees, accepted_event)
      end
    end

    context 'when filtering with color filters' do
      let(:green_event) do
        EventFactory.timed_event(
          summary: 'Green Event',
          color_id: EventFactory::GREEN,
          start_time: DateTime.new(2024, 1, 1, 10, 0, 0),
          duration_hours: 1.0
        )
      end
      let(:blue_event) do
        EventFactory.timed_event(
          summary: 'Blue Event',
          color_id: EventFactory::BLUE,
          start_time: DateTime.new(2024, 1, 2, 14, 0, 0),
          duration_hours: 2.0
        )
      end
      let(:red_event) do
        EventFactory.timed_event(
          summary: 'Red Event',
          color_id: EventFactory::RED,
          start_time: DateTime.new(2024, 1, 3, 9, 0, 0),
          duration_hours: 1.5
        )
      end

      before do
        # すべてのイベントが参加済みとして扱われるように設定
        allow(green_event).to receive(:attended_by?).with(user_email).and_return(true)
        allow(blue_event).to receive(:attended_by?).with(user_email).and_return(true)
        allow(red_event).to receive(:attended_by?).with(user_email).and_return(true)
      end

      context 'when include_colors is specified' do
        it 'should return only events with included colors using color names' do
          events = [green_event, blue_event, red_event]
          result = service.apply_filters(events, user_email, include_colors: ["緑", "青"])

          expect(result).to contain_exactly(green_event, blue_event)
        end
      end

      context 'when exclude_colors is specified' do
        it 'should return events excluding specified colors using color names' do
          events = [green_event, blue_event, red_event]
          result = service.apply_filters(events, user_email, exclude_colors: ["赤"])

          expect(result).to contain_exactly(green_event, blue_event)
        end
      end

      context 'when both include_colors and exclude_colors are specified' do
        it 'should prioritize include_colors over exclude_colors' do
          events = [green_event, blue_event, red_event]
          result = service.apply_filters(events, user_email,
                                        include_colors: ["緑", "赤"],
                                        exclude_colors: ["青"])

          expect(result).to contain_exactly(green_event, red_event)
        end
      end
    end
  end
end
