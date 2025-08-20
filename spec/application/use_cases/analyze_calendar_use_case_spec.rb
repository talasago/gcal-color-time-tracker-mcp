require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/application/use_cases/analyze_calendar_use_case'
require_relative '../../support/event_factory'

RSpec.describe Application::AnalyzeCalendarUseCase do
  let(:mock_calendar_repository) { instance_double('Infrastructure::GoogleCalendarRepository') }
  let(:mock_token_repository) { instance_double('Infrastructure::TokenRepository') }

  subject(:use_case) do
    Application::AnalyzeCalendarUseCase.new(
      calendar_repository: mock_calendar_repository,
      token_repository: mock_token_repository
    )
  end

  let(:start_date) { Date.parse('2024-01-01') }
  let(:end_date) { Date.parse('2024-01-31') }
  let(:user_email) { 'test@example.com' }
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

  let(:mock_analysis_result) do
    {
      color_breakdown: { '2' => 1 },
      summary: { total_events: 1, total_duration: 3600 }
    }
  end


  describe '#execute' do
    context 'when user is authenticated' do
      before do
        allow(mock_token_repository).to receive(:token_exist?).and_return(true)
        allow(mock_calendar_repository).to receive(:fetch_events).and_return([green_event])
        allow(mock_calendar_repository).to receive(:get_user_email).and_return(user_email)
      end

      it 'should analyze calendar events successfully and return analysis data' do
        result = use_case.execute(
          start_date: start_date,
          end_date: end_date,
        )

        aggregate_failures do
          expect(result[:color_breakdown]).to have_key('緑')
          expect(result[:color_breakdown]['緑'][:event_count]).to eq(1)
          expect(result[:color_breakdown]['緑'][:total_hours]).to eq(1.0)
          expect(result[:summary][:total_events]).to eq(1)
          expect(result[:summary][:total_hours]).to eq(1.0)
          expect(result[:parsed_start_date]).to eq(start_date)
          expect(result[:parsed_end_date]).to eq(end_date)
        end
      end

      context 'color filters' do
        let(:all_events) { [green_event, blue_event] }

        before do
          allow(mock_calendar_repository).to receive(:fetch_events).and_return(all_events)
        end

        it 'should return filtered events when include_colors is specified' do

          result = use_case.execute(
            start_date: start_date,
            end_date: end_date,
            include_colors: [EventFactory::GREEN, "緑"]
          )

          expect(result[:color_breakdown]['緑'][:event_count]).to eq(1)
          expect(result[:summary][:total_events]).to eq(1)
        end

        it 'should return all events when no color filters are provided' do

          result = use_case.execute(
            start_date: start_date,
            end_date: end_date
          )

          expect(result[:summary][:total_events]).to eq(2)
          expect(result[:color_breakdown]).to have_key('緑')
          expect(result[:color_breakdown]).to have_key('青')
        end

        it 'should return filtered events when exclude_colors is specified' do

          result = use_case.execute(
            start_date: start_date,
            end_date: end_date,
            exclude_colors: [EventFactory::BLUE, "青"]
          )

          expect(result[:color_breakdown]['緑'][:event_count]).to eq(1)
          expect(result[:color_breakdown]).not_to have_key('青')
        end
      end
    end

    context 'when user is not authenticated' do
      before do
        allow(mock_token_repository).to receive(:token_exist?).and_return(false)
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
        allow(mock_token_repository).to receive(:token_exist?).and_return(true)
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
