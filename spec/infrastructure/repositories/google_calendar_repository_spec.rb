require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/infrastructure/repositories/google_calendar_repository'

describe Infrastructure::GoogleCalendarRepository do
  let(:mock_service) { instance_double(Google::Apis::CalendarV3::CalendarService) }
  let(:start_date) { Date.new(2024, 1, 1) }
  let(:end_date) { Date.new(2024, 1, 31) }
  let(:mock_events) { ['event1', 'event2', 'event3'] }
  let(:mock_response) { double('response', items: mock_events) }

  subject(:repository) { described_class.new }

  before do
    allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(mock_service)
  end

  describe '#initialize' do
    context 'when initializing repository' do
      it 'should create a Google Calendar service instance' do
        expect(Google::Apis::CalendarV3::CalendarService).to receive(:new)
        
        described_class.new
      end
    end
  end

  describe '#fetch_events' do
    context 'when fetching events successfully' do
      before do
        allow(mock_service).to receive(:list_events).and_return(mock_response)
      end

      it 'should fetch events from Google Calendar API' do
        result = repository.fetch_events(start_date, end_date)

        expect(result).to eq(mock_events)
        expect(mock_service).to have_received(:list_events).with(
          'primary',
          time_min: Time.new(2024, 1, 1, 0, 0, 0).iso8601,
          time_max: Time.new(2024, 1, 31, 23, 59, 59).iso8601,
          single_events: true,
          order_by: 'startTime'
        )
      end
    end

    context 'when API returns error' do
      before do
        allow(mock_service).to receive(:list_events)
          .and_raise(Google::Apis::ClientError.new('API Error'))
      end

      it 'should raise CalendarApiError' do
        expect { repository.fetch_events(start_date, end_date) }
          .to raise_error(CalendarColorMCP::CalendarApiError, /API Error/)
      end
    end
  end

  describe '#get_user_email' do
    let(:mock_calendar_info) { double('calendar_info', id: 'test@example.com') }

    context 'when getting user email successfully' do
      before do
        allow(mock_service).to receive(:get_calendar).with('primary').and_return(mock_calendar_info)
      end

      it 'should return user email' do
        result = repository.get_user_email

        expect(result).to eq('test@example.com')
      end
    end

    context 'when API returns error' do
      before do
        allow(mock_service).to receive(:get_calendar)
          .and_raise(Google::Apis::ClientError.new('API Error'))
      end

      it 'should raise CalendarApiError' do
        expect { repository.get_user_email }
          .to raise_error(CalendarColorMCP::CalendarApiError, /API Error/)
      end
    end
  end
end

describe Infrastructure::GoogleCalendarRepositoryDebugDecorator do
  let(:mock_repository) { instance_double(Infrastructure::GoogleCalendarRepository) }
  let(:start_date) { Date.new(2024, 1, 1) }
  let(:end_date) { Date.new(2024, 1, 31) }
  let(:mock_events) { [mock_event1, mock_event2] }
  
  let(:mock_event1) do
    double('event1',
      summary: 'Test Event 1',
      color_id: '1',
      start: double(date_time: Time.parse('2024-01-01 10:00:00'), date: nil),
      end: double(date_time: Time.parse('2024-01-01 11:00:00'), date: nil)
    )
  end
  
  let(:mock_event2) do
    double('event2',
      summary: 'Test Event 2',
      color_id: '2',
      start: double(date_time: nil, date: Date.parse('2024-01-02')),
      end: double(date_time: nil, date: Date.parse('2024-01-02'))
    )
  end

  subject(:decorator) { Infrastructure::GoogleCalendarRepositoryDebugDecorator.new(mock_repository) }

  describe '#fetch_events' do
    before do
      allow(mock_repository).to receive(:fetch_events).with(start_date, end_date).and_return(mock_events)
    end

    it 'should delegate to repository and return events' do
      result = decorator.fetch_events(start_date, end_date)

      expect(result).to eq(mock_events)
      expect(mock_repository).to have_received(:fetch_events).with(start_date, end_date)
    end

    it 'should log debug information' do
      expect(decorator).to receive(:logger).at_least(:once).and_return(double(debug: nil))

      decorator.fetch_events(start_date, end_date)
    end
  end

  describe '#get_user_email' do
    let(:user_email) { 'test@example.com' }

    before do
      allow(mock_repository).to receive(:get_user_email).and_return(user_email)
    end

    it 'should delegate to repository and return email' do
      result = decorator.get_user_email

      expect(result).to eq(user_email)
      expect(mock_repository).to have_received(:get_user_email)
    end

    it 'should log debug information' do
      expect(decorator).to receive(:logger).and_return(double(debug: nil))

      decorator.get_user_email
    end
  end

  describe '#authorize' do
    let(:mock_credentials) { double('credentials') }

    before do
      allow(mock_repository).to receive(:authorize)
    end

    it 'should delegate to repository' do
      decorator.authorize(mock_credentials)

      expect(mock_repository).to have_received(:authorize).with(mock_credentials)
    end

    it 'should log debug information' do
      expect(decorator).to receive(:logger).and_return(double(debug: nil))

      decorator.authorize(mock_credentials)
    end
  end
end