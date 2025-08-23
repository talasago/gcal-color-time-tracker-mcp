require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/infrastructure/repositories/google_calendar_repository'
require_relative '../../support/event_factory'

describe Infrastructure::GoogleCalendarRepository do
  let(:mock_service) { instance_double(Google::Apis::CalendarV3::CalendarService) }
  let(:start_date) { Date.new(2024, 1, 1) }
  let(:end_date) { Date.new(2024, 1, 31) }

  subject(:repository) { described_class.new }

  before do
    allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(mock_service)
    allow(mock_service).to receive(:authorization=)
  end



  describe '#fetch_events' do
    let(:mock_token_repository) { instance_double(Infrastructure::TokenRepository) }

    before do
      allow(Infrastructure::TokenRepository).to receive(:instance).and_return(mock_token_repository)
    end

    context 'when fetching events successfully' do
      let(:mock_credentials) { double('credentials', expired?: false) }
      let(:mock_api_events) { [EventFactory.simple_api_event] }

      before do
        allow(mock_token_repository).to receive(:load_credentials).and_return(mock_credentials)
        allow(mock_service).to receive(:authorization=)

        mock_response = double('response')
        allow(mock_response).to receive(:items).and_return(mock_api_events)
        allow(mock_service).to receive(:list_events).and_return(mock_response)
      end

      it 'should return Domain::CalendarEvent objects from API response' do
        result = repository.fetch_events(start_date, end_date)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result.first).to be_a(Domain::CalendarEvent)
        expect(result.first.summary).to eq('Test Event')
        expect(result.first.color_id).to eq(1)
      end

      context 'when API event has attendees and organizer' do
        let(:mock_api_events) { [EventFactory.api_event_with_attendees] }

        it 'should convert attendees to Domain::Attendee objects' do
          result = repository.fetch_events(start_date, end_date)
          event = result.first

          expect(event.attendees).to be_an(Array)
          expect(event.attendees.length).to eq(2)

          attendee1 = event.attendees[0]
          expect(attendee1).to be_a(Domain::Attendee)
          expect(attendee1.email).to eq('attendee1@example.com')
          expect(attendee1.response_status).to eq('accepted')
          expect(attendee1.self?).to be(false)

          attendee2 = event.attendees[1]
          expect(attendee2).to be_a(Domain::Attendee)
          expect(attendee2.email).to eq('attendee2@example.com')
          expect(attendee2.response_status).to eq('declined')
          expect(attendee2.self?).to be(true)
        end

        it 'should convert organizer to Domain::Organizer object' do
          result = repository.fetch_events(start_date, end_date)
          event = result.first
          organizer = event.organizer

          expect(organizer).to be_a(Domain::Organizer)
          expect(organizer.email).to eq('organizer@example.com')
          expect(organizer.display_name).to eq('Meeting Organizer')
          expect(organizer.self?).to be(false)
        end
      end

      context 'when API event has nil attendees and organizer' do
        let(:mock_api_events) { [EventFactory.api_event_with_nil_values] }

        it 'should return empty array for nil attendees' do
          result = repository.fetch_events(start_date, end_date)
          event = result.first

          expect(event.attendees).to eq([])
        end

        it 'should return nil for nil organizer' do
          result = repository.fetch_events(start_date, end_date)
          event = result.first

          expect(event.organizer).to be_nil
        end
      end

      context 'when handling malformed API response data' do
        it 'should handle missing summary gracefully' do
          mock_api_events = [EventFactory.simple_api_event(summary: nil)]
          mock_response = double('response')
          allow(mock_response).to receive(:items).and_return(mock_api_events)
          allow(mock_service).to receive(:list_events).and_return(mock_response)

          result = repository.fetch_events(start_date, end_date)
          expect(result.first.summary).to be_nil
        end

        it 'should handle invalid color_id formats' do
          mock_api_events = [EventFactory.simple_api_event(color_id: 'invalid')]
          mock_response = double('response')
          allow(mock_response).to receive(:items).and_return(mock_api_events)
          allow(mock_service).to receive(:list_events).and_return(mock_response)

          result = repository.fetch_events(start_date, end_date)
          expect(result.first.color_id).to eq(0)
        end

        it 'should handle attendees without email' do
          mock_api_events = [EventFactory.api_event_with_invalid_data]
          mock_response = double('response')
          allow(mock_response).to receive(:items).and_return(mock_api_events)
          allow(mock_service).to receive(:list_events).and_return(mock_response)

          result = repository.fetch_events(start_date, end_date)
          # エラーを起こさずに処理できることを確認
          expect(result).to be_an(Array)
          expect(result.first).to be_a(Domain::CalendarEvent)
        end
      end

      context 'when handling datetime conversion edge cases' do
        it 'should handle all-day events (date instead of datetime)' do
          mock_api_events = [EventFactory.all_day_api_event]
          mock_response = double('response')
          allow(mock_response).to receive(:items).and_return(mock_api_events)
          allow(mock_service).to receive(:list_events).and_return(mock_response)

          result = repository.fetch_events(start_date, end_date)
          event = result.first

          expect(event.start_time).to be_a(Time)
          expect(event.end_time).to be_a(Time)
          expect(event.start_time.hour).to eq(0)
          expect(event.start_time.min).to eq(0)
        end

        it 'should handle events with same start and end time' do
          same_time = Time.parse('2024-01-01 10:00:00')
          mock_api_events = [EventFactory.simple_api_event(
            start_time: same_time,
            end_time: same_time
          )]
          mock_response = double('response')
          allow(mock_response).to receive(:items).and_return(mock_api_events)
          allow(mock_service).to receive(:list_events).and_return(mock_response)

          result = repository.fetch_events(start_date, end_date)
          event = result.first

          expect(event.start_time).to eq(event.end_time)
          expect(event.end_time - event.start_time).to eq(0)
        end
      end

      context 'when handling empty or minimal data' do
        it 'should handle API response with empty items array' do
          mock_response = double('response', items: [])
          allow(mock_service).to receive(:list_events).and_return(mock_response)

          result = repository.fetch_events(start_date, end_date)
          expect(result).to eq([])
        end

        it 'should handle events with empty attendees array vs nil attendees' do
          event_with_empty = EventFactory.simple_api_event(attendees: [])
          event_with_nil = EventFactory.api_event_with_nil_values

          mock_response = double('response', items: [event_with_empty, event_with_nil])
          allow(mock_service).to receive(:list_events).and_return(mock_response)

          result = repository.fetch_events(start_date, end_date)
          expect(result[0].attendees).to eq([])
          expect(result[1].attendees).to eq([])
        end
      end
    end

    context 'when credentials are not found' do
      before do
        allow(mock_token_repository).to receive(:load_credentials).and_return(nil)
      end

      it 'should raise AuthenticationRequiredError' do
        expect { repository.fetch_events(start_date, end_date) }
          .to raise_error(Application::AuthenticationRequiredError, /Authentication credentials not found/)
      end
    end

    context 'when credentials are expired' do
      let(:expired_credentials) { double('credentials', expired?: true) }

      before do
        allow(mock_token_repository).to receive(:load_credentials).and_return(expired_credentials)
        allow(expired_credentials).to receive(:refresh!)
        allow(mock_token_repository).to receive(:save_credentials)
        allow(mock_service).to receive(:authorization=)

        mock_response = double('response')
        allow(mock_response).to receive(:items).and_return([])
        allow(mock_service).to receive(:list_events).and_return(mock_response)
      end

      it 'should refresh credentials and continue with fetch' do
        result = repository.fetch_events(start_date, end_date)

        expect(expired_credentials).to have_received(:refresh!)
        expect(mock_token_repository).to have_received(:save_credentials).with(expired_credentials)
        expect(mock_service).to have_received(:authorization=).with(expired_credentials)
        expect(result).to be_an(Array)
      end

      context 'when refresh fails' do
        before do
          allow(expired_credentials).to receive(:refresh!)
            .and_raise(Google::Apis::AuthorizationError.new('Refresh failed'))
        end

        it 'should raise AuthenticationRequiredError' do
          expect { repository.fetch_events(start_date, end_date) }
            .to raise_error(Application::AuthenticationRequiredError, /Failed to refresh token/)
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
          .to raise_error(Application::AuthenticationRequiredError, /Authentication error/)
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

    it 'should log debug information about fetch operation' do
      mock_logger = double('logger')
      allow(decorator).to receive(:logger).and_return(mock_logger)

      expect(mock_logger).to receive(:debug).with("=== Google Calendar API Response Debug ===")
      expect(mock_logger).to receive(:debug).with("Period: #{start_date} ~ #{end_date}")
      expect(mock_logger).to receive(:debug).with("Total events: 2")
      expect(mock_logger).to receive(:debug).with("--- Event 1 ---")
      expect(mock_logger).to receive(:debug).with("Title: Test Event 1")
      expect(mock_logger).to receive(:debug).with("color_id: 1")
      expect(mock_logger).to receive(:debug).with("start_time: 2024-01-01 10:00:00 +0900")
      expect(mock_logger).to receive(:debug).with("end_time: 2024-01-01 11:00:00 +0900")
      expect(mock_logger).to receive(:debug).with("duration_hours: 1.0")
      expect(mock_logger).to receive(:debug).with("--- Event 2 ---")
      expect(mock_logger).to receive(:debug).with("Title: Test Event 2")
      expect(mock_logger).to receive(:debug).with("color_id: 2")
      expect(mock_logger).to receive(:debug).with("start_time: 2024-01-02 00:00:00 +0900")
      expect(mock_logger).to receive(:debug).with("end_time: 2024-01-02 23:59:59 +0900")
      expect(mock_logger).to receive(:debug).with(match(/duration_hours: 23\.99972222222222/))
      expect(mock_logger).to receive(:debug).with("=" * 50)

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

    it 'should log debug information about user email retrieval' do
      mock_logger = double('logger')
      allow(decorator).to receive(:logger).and_return(mock_logger)

      expect(mock_logger).to receive(:debug).with("Retrieved user email: #{user_email}")

      decorator.get_user_email
    end
  end

end
