require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/infrastructure/repositories/google_calendar_repository'

# TODO: attendeesとorganizerクラスが作られていることのテストが必要追加

describe Infrastructure::GoogleCalendarRepository do
  let(:mock_service) { instance_double(Google::Apis::CalendarV3::CalendarService) }
  let(:start_date) { Date.new(2024, 1, 1) }
  let(:end_date) { Date.new(2024, 1, 31) }
  let(:mock_api_event) do
    double('api_event').tap do |event|
      allow(event).to receive(:summary).and_return('Test Event')
      allow(event).to receive(:color_id).and_return('1')
      allow(event).to receive(:attendees).and_return(nil)
      allow(event).to receive(:organizer).and_return(nil)

      start_obj = double('start')
      allow(start_obj).to receive(:date_time).and_return(Time.parse('2024-01-01 10:00:00'))
      allow(start_obj).to receive(:date).and_return(nil)
      allow(event).to receive(:start).and_return(start_obj)

      end_obj = double('end')
      allow(end_obj).to receive(:date_time).and_return(Time.parse('2024-01-01 11:00:00'))
      allow(end_obj).to receive(:date).and_return(nil)
      allow(event).to receive(:end).and_return(end_obj)
    end
  end

  let(:mock_events) { [mock_api_event] }
  let(:mock_response) { double('response', items: mock_events) }

  subject(:repository) { described_class.new }

  before do
    allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(mock_service)
    allow(mock_service).to receive(:authorization=)
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
    let(:mock_token_repository) { instance_double(Infrastructure::TokenRepository) }

    before do
      allow(Infrastructure::TokenRepository).to receive(:instance).and_return(mock_token_repository)
    end

    context 'when fetching events successfully' do
      let(:mock_credentials) { double('credentials', expired?: false) }

      before do
        allow(mock_token_repository).to receive(:load_credentials).and_return(mock_credentials)
        allow(mock_service).to receive(:authorization=)
        allow(mock_service).to receive(:list_events).and_return(mock_response)
      end

      it 'should fetch events from Google Calendar API and convert to Domain objects' do
        result = repository.fetch_events(start_date, end_date)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result.first).to be_a(Domain::CalendarEvent)
        expect(result.first.summary).to eq('Test Event')
        expect(result.first.color_id).to eq(1)

        expect(mock_service).to have_received(:list_events).with(
          'primary',
          time_min: Time.new(2024, 1, 1, 0, 0, 0).iso8601,
          time_max: Time.new(2024, 1, 31, 23, 59, 59).iso8601,
          single_events: true,
          order_by: 'startTime'
        )
      end

      it 'should set authorization on service with valid credentials' do
        repository.fetch_events(start_date, end_date)

        expect(mock_service).to have_received(:authorization=).with(mock_credentials)
      end
    end

    context 'when credentials are not found' do
      before do
        allow(mock_token_repository).to receive(:load_credentials).and_return(nil)
      end

      it 'should raise AuthenticationRequiredError' do
        expect { repository.fetch_events(start_date, end_date) }
          .to raise_error(Application::AuthenticationRequiredError, /認証情報が見つかりません/)
      end
    end

    context 'when credentials are expired' do
      let(:expired_credentials) { double('credentials', expired?: true) }

      before do
        allow(mock_token_repository).to receive(:load_credentials).and_return(expired_credentials)
        allow(expired_credentials).to receive(:refresh!)
        allow(mock_token_repository).to receive(:save_credentials)
        allow(mock_service).to receive(:authorization=)
        allow(mock_service).to receive(:list_events).and_return(mock_response)
      end

      it 'should refresh credentials and continue with fetch' do
        repository.fetch_events(start_date, end_date)

        expect(expired_credentials).to have_received(:refresh!)
        expect(mock_token_repository).to have_received(:save_credentials).with(expired_credentials)
        expect(mock_service).to have_received(:authorization=).with(expired_credentials)
      end

      context 'when refresh fails' do
        before do
          allow(expired_credentials).to receive(:refresh!)
            .and_raise(Google::Apis::AuthorizationError.new('Refresh failed'))
        end

        it 'should raise AuthenticationRequiredError' do
          expect { repository.fetch_events(start_date, end_date) }
            .to raise_error(Application::AuthenticationRequiredError, /トークンのリフレッシュに失敗しました/)
        end
      end
    end

    context 'when API returns authorization error' do
      let(:mock_credentials) { double('credentials', expired?: false) }

      before do
        allow(mock_token_repository).to receive(:load_credentials).and_return(mock_credentials)
        allow(mock_service).to receive(:authorization=)
        allow(mock_service).to receive(:list_events)
          .and_raise(Google::Apis::AuthorizationError.new('Authorization Error'))
      end

      it 'should raise AuthenticationRequiredError' do
        expect { repository.fetch_events(start_date, end_date) }
          .to raise_error(Application::AuthenticationRequiredError, /認証エラー/)
      end
    end

    context 'when API returns client error' do
      let(:mock_credentials) { double('credentials', expired?: false) }

      before do
        allow(mock_token_repository).to receive(:load_credentials).and_return(mock_credentials)
        allow(mock_service).to receive(:authorization=)
        allow(mock_service).to receive(:list_events)
          .and_raise(Google::Apis::ClientError.new('API Error'))
      end

      it 'should raise ExternalServiceError' do
        expect { repository.fetch_events(start_date, end_date) }
          .to raise_error(Infrastructure::ExternalServiceError, /API Error/)
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

      it 'should raise ExternalServiceError' do
        expect { repository.get_user_email }
          .to raise_error(Infrastructure::ExternalServiceError, /API Error/)
      end
    end
  end
end

describe Infrastructure::GoogleCalendarRepositoryLogDecorator do
  let(:mock_repository) { instance_double(Infrastructure::GoogleCalendarRepository) }
  let(:start_date) { Date.new(2024, 1, 1) }
  let(:end_date) { Date.new(2024, 1, 31) }
  let(:mock_events) { [mock_event1, mock_event2] }

  let(:mock_event1) do
    Domain::CalendarEvent.new(
      summary: 'Test Event 1',
      start_time: Time.parse('2024-01-01 10:00:00'),
      end_time: Time.parse('2024-01-01 11:00:00'),
      color_id: 1,
      attendees: [],
      organizer: nil
    )
  end

  let(:mock_event2) do
    Domain::CalendarEvent.new(
      summary: 'Test Event 2',
      start_time: Time.parse('2024-01-02 00:00:00'),
      end_time: Time.parse('2024-01-02 23:59:59'),
      color_id: 2,
      attendees: [],
      organizer: nil
    )
  end

  subject(:decorator) { Infrastructure::GoogleCalendarRepositoryLogDecorator.new(mock_repository) }

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

end
