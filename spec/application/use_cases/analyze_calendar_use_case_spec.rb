require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/application/use_cases/analyze_calendar_use_case'

RSpec.describe Application::AnalyzeCalendarUseCase do
  let(:mock_calendar_repository) { instance_double('GoogleCalendarRepository') }
  let(:mock_filter_service) { instance_double('EventFilterService') }
  let(:mock_analyzer_service) { instance_double('TimeAnalyzer') }
  let(:mock_token_manager) { CalendarColorMCP::TokenManager.instance }
  let(:mock_auth_manager) { CalendarColorMCP::GoogleCalendarAuthManager.instance }

  subject(:use_case) do
    Application::AnalyzeCalendarUseCase.new(
      calendar_repository: mock_calendar_repository,
      filter_service: mock_filter_service,
      analyzer_service: mock_analyzer_service,
      token_manager: mock_token_manager,
      auth_manager: mock_auth_manager
    )
  end

  let(:start_date) { Date.parse('2024-01-01') }
  let(:end_date) { Date.parse('2024-01-31') }
  let(:user_email) { 'test@example.com' }
  let(:mock_event) { double('event', summary: 'Test Event') }
  let(:mock_analysis_result) { { color_breakdown: {}, summary: { total_hours: 10 } } }

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
        allow(mock_filter_service).to receive(:apply_filters).and_return([mock_event])
        allow(mock_analyzer_service).to receive(:analyze).and_return(mock_analysis_result)
      end

      it 'should analyze calendar events successfully' do
        result = use_case.execute(
          start_date: start_date,
          end_date: end_date,
        )

        expect(result).to eq(mock_analysis_result)
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

    context 'when date parameters are nil' do
      before do
        allow(mock_token_manager).to receive(:token_exist?).and_return(true)
      end

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
  end
end
