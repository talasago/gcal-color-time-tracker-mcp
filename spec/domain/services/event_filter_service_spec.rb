require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/domain/services/event_filter_service'
require_relative '../../../lib/calendar_color_mcp/domain/entities/calendar_event'

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
        result = service.apply_filters(all_events, nil, user_email)

        expect(result).to include(organizer_event, private_event, private_event_empty_attendees, accepted_event)
        expect(result).not_to include(declined_event, tentative_event, needs_action_event, not_invited_event)
        expect(result.length).to eq(4)
      end
    end
  end
end
