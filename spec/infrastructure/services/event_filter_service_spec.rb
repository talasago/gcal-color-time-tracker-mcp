require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/infrastructure/services/event_filter_service'

describe Infrastructure::EventFilterService do
  subject(:service) { described_class.new }

  let(:user_email) { 'test@example.com' }

  let(:organizer_event) do
    double('event',
      summary: '主催者イベント',
      organizer: double(self: true),
      attendees: nil
    )
  end

  let(:private_event) do
    double('event',
      summary: 'プライベートイベント',
      organizer: double(self: false),
      attendees: nil
    )
  end

  let(:private_event_empty_attendees) do
    double('event',
      summary: 'プライベートイベント（空配列）',
      organizer: double(self: false),
      attendees: []
    )
  end

  let(:accepted_event) do
    double('event',
      summary: '承認済みイベント',
      organizer: double(self: false),
      attendees: [
        double(email: 'test@example.com', self: true, response_status: 'accepted')
      ]
    )
  end

  let(:declined_event) do
    double('event',
      summary: '辞退イベント',
      organizer: double(self: false),
      attendees: [
        double(email: 'test@example.com', self: true, response_status: 'declined')
      ]
    )
  end

  let(:tentative_event) do
    double('event',
      summary: '仮承認イベント',
      organizer: double(self: false),
      attendees: [
        double(email: 'test@example.com', self: true, response_status: 'tentative')
      ]
    )
  end

  let(:needs_action_event) do
    double('event',
      summary: '未応答イベント',
      organizer: double(self: false),
      attendees: [
        double(email: 'test@example.com', self: true, response_status: 'needsAction')
      ]
    )
  end

  let(:not_invited_event) do
    double('event',
      summary: '未招待イベント',
      organizer: double(self: false),
      attendees: [
        double(email: 'other@example.com', self: false, response_status: 'accepted')
      ]
    )
  end

  describe '#filter_attended_events' do
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

    context 'when filtering attended events' do
      it 'should return only attended events' do
        result = service.filter_attended_events(all_events, user_email)

        expect(result).to include(organizer_event, private_event, private_event_empty_attendees, accepted_event, not_invited_event)
        expect(result).not_to include(declined_event, tentative_event, needs_action_event)
        expect(result.length).to eq(5)
      end
    end
  end
end
