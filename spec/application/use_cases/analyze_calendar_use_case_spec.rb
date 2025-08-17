require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/application/use_cases/analyze_calendar_use_case'

RSpec.describe Application::AnalyzeCalendarUseCase do
  let(:mock_calendar_repository) { instance_double('GoogleCalendarRepository') }
  let(:mock_token_manager) { CalendarColorMCP::TokenManager.instance }
  let(:mock_auth_manager) { CalendarColorMCP::GoogleCalendarAuthManager.instance }

  subject(:use_case) do
    Application::AnalyzeCalendarUseCase.new(
      calendar_repository: mock_calendar_repository,
      token_manager: mock_token_manager,
      auth_manager: mock_auth_manager
    )
  end

  let(:start_date) { Date.parse('2024-01-01') }
  let(:end_date) { Date.parse('2024-01-31') }
  let(:user_email) { 'test@example.com' }
  let(:mock_event) do
    double('event',
      summary: 'Test Event',
      color_id: '2',
      start: double('start', date_time: Time.parse('2024-01-01 10:00:00'), date: nil),
      end: double('end', date_time: Time.parse('2024-01-01 11:00:00'), date: nil),
      attendees: nil,
      organizer: double('organizer', self: true)
    ).tap do |event|
      allow(event).to receive(:attended_by?).with(user_email).and_return(true)
    end
  end

  describe '#initialize' do
    it 'should initialize with dependencies' do
      expect(use_case).to be_a(Application::AnalyzeCalendarUseCase)
    end
  end

  describe '#execute' do
    context 'when user is authenticated' do
      before do
        allow(mock_token_manager).to receive(:token_exist?).and_return(true)
        allow(mock_calendar_repository).to receive(:fetch_events).and_return([mock_event])
        allow(mock_calendar_repository).to receive(:get_user_email).and_return(user_email)
      end

      it 'should analyze calendar events successfully' do
        result = use_case.execute(
          start_date: start_date,
          end_date: end_date,
        )

        expect(result).to be_a(Hash)
        expect(result).to have_key(:color_breakdown)
        expect(result).to have_key(:summary)
        expect(mock_calendar_repository).to have_received(:fetch_events).with(
          start_date,
          end_date
        )
      end
    end

    context 'when user is not authenticated' do
      before do
        allow(mock_token_manager).to receive(:token_exist?).and_return(false)
      end

      it 'should raise AuthenticationRequiredError' do
        expect {
          use_case.execute(
            start_date: start_date,
            end_date: end_date,
          )
        }.to raise_error(Application::AuthenticationRequiredError)
      end
    end

    context 'when date parameters are invalid' do
      before do
        allow(mock_token_manager).to receive(:token_exist?).and_return(true)
      end

      context 'when dates are nil' do
        where(:case_name, :test_start_date, :test_end_date) do
          [
            ['start_date is nil', nil, Date.parse('2024-01-31')],
            ['end_date is nil', Date.parse('2024-01-01'), nil],
            ['both dates are nil', nil, nil]
          ]
        end

        with_them do
          it 'should raise InvalidParameterError' do
            expect {
              use_case.execute(
                start_date: test_start_date,
                end_date: test_end_date,
              )
            }.to raise_error(Application::InvalidParameterError, "Both start date and end date must be provided")
          end
        end
      end

      context 'when date format is invalid' do
        where(:case_name, :test_start_date, :test_end_date, :expected_message) do
          [
            ['invalid start date format', 'invalid-date', '2024-01-31', /Invalid date format/],
            ['invalid end date format', '2024-01-01', 'invalid-date', /Invalid date format/],
            ['both dates invalid format', 'invalid-start', 'invalid-end', /Invalid date format/]
          ]
        end

        with_them do
          it 'should raise InvalidParameterError with date format message' do
            expect {
              use_case.execute(
                start_date: test_start_date,
                end_date: test_end_date,
              )
            }.to raise_error(Application::InvalidParameterError, expected_message)
          end
        end
      end

      context 'when end date is before start date' do
        it 'should raise InvalidParameterError' do
          expect {
            use_case.execute(
              start_date: '2024-01-31',
              end_date: '2024-01-01',
            )
          }.to raise_error(Application::InvalidParameterError, "End date must be after start date")
        end
      end
    end
  end
end
