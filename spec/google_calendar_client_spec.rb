require 'spec_helper'
require_relative '../lib/calendar_color_mcp/google_calendar_client'

# TODO: このテストファイルは正常系のテストのみを実装しています
# 異常系テスト（エラーハンドリング、認証失敗等）は設計変更の可能性があるため未実装です
# 今後必要に応じて異常系テストを追加予定

describe CalendarColorMCP::GoogleCalendarClient do
  let(:mock_service) { instance_double(Google::Apis::CalendarV3::CalendarService) }
  let(:mock_token_manager) { instance_double(CalendarColorMCP::TokenManager) }
  let(:mock_credentials) { instance_double(Google::Auth::UserRefreshCredentials) }
  let(:mock_calendar_info) { double('calendar_info', id: 'test@example.com') }

  before do
    allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(mock_service)
    allow(CalendarColorMCP::TokenManager).to receive(:instance).and_return(mock_token_manager)
    allow(mock_token_manager).to receive(:load_credentials).and_return(mock_credentials)
    allow(mock_credentials).to receive(:expired?).and_return(false)
    allow(mock_service).to receive(:authorization=)
    allow(mock_service).to receive(:get_calendar).with('primary').and_return(mock_calendar_info)
  end

  describe '#initialize' do
    subject { described_class.new }

    context 'when initializing client successfully' do
      it 'should not be authenticated initially' do
        client = subject

        expect(client.instance_variable_get(:@authenticated)).to be false
      end
    end
  end

  describe '#get_events' do
    subject { client.get_events(start_date, end_date) }

    let(:client) { described_class.new }
    let(:start_date) { Date.new(2024, 1, 1) }
    let(:end_date) { Date.new(2024, 1, 31) }

    let(:organizer_event) do
      double('event',
        summary: '主催者イベント',
        color_id: '1',
        start: double(date_time: Time.new(2024, 1, 15, 10, 0, 0), date: nil),
        end: double(date_time: Time.new(2024, 1, 15, 11, 0, 0), date: nil),
        organizer: double(self: true),
        attendees: nil
      )
    end

    let(:private_event) do
      double('event',
        summary: 'プライベートイベント',
        color_id: '2',
        start: double(date_time: Time.new(2024, 1, 20, 14, 0, 0), date: nil),
        end: double(date_time: Time.new(2024, 1, 20, 15, 0, 0), date: nil),
        organizer: double(self: false),
        attendees: nil
      )
    end

    let(:accepted_event) do
      double('event',
        summary: '承認済みイベント',
        color_id: '3',
        start: double(date_time: Time.new(2024, 1, 25, 9, 0, 0), date: nil),
        end: double(date_time: Time.new(2024, 1, 25, 10, 0, 0), date: nil),
        organizer: double(self: false),
        attendees: [
          double(email: 'test@example.com', self: true, response_status: 'accepted')
        ]
      )
    end

    let(:declined_event) do
      double('event',
        summary: '辞退イベント',
        color_id: '4',
        start: double(date_time: Time.new(2024, 1, 28, 16, 0, 0), date: nil),
        end: double(date_time: Time.new(2024, 1, 28, 17, 0, 0), date: nil),
        organizer: double(self: false),
        attendees: [
          double(email: 'test@example.com', self: true, response_status: 'declined')
        ]
      )
    end

    let(:all_events) { [organizer_event, private_event, accepted_event, declined_event] }
    let(:mock_events_response) { double('events_response', items: all_events) }

    before do
      allow(mock_service).to receive(:list_events).and_return(mock_events_response)
    end

    context 'when getting events successfully' do
      it 'should return only organizer, private, and accepted events' do
        expect(subject).to include(organizer_event, private_event, accepted_event)
        expect(subject).not_to include(declined_event)
        expect(subject.length).to eq(3)
      end
    end
  end
end
