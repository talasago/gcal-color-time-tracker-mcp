require 'spec_helper'
require_relative '../../support/mcp_request_helpers'
require_relative '../../support/mcp_shared_examples'
require_relative '../../support/mcp_shared_contexts'
require_relative '../../../lib/calendar_color_mcp/interface_adapters/tools/analyze_calendar_tool'

RSpec.describe 'AnalyzeCalendarTool', type: :request do
  include MCPRequestHelpers
  include MCPSharedHelpers

  describe 'date range validation' do
    include_context 'calendar analysis setup'

    shared_examples 'valid date range processing' do |start_date, end_date, expected_days, description|
      it "should handle #{description}" do
        response = InterfaceAdapters::AnalyzeCalendarTool.call(
          start_date: start_date,
          end_date: end_date,
          server_context: server_context
        )
        content = JSON.parse(response.content[0][:text])

        expect(content['success']).to be true
        expect(content['period']['start_date']).to eq(start_date)
        expect(content['period']['end_date']).to eq(end_date)
        expect(content['period']['days']).to eq(expected_days)
      end
    end

    context 'when handling non-leap year dates' do
      include_examples 'valid date range processing', '2023-01-01', '2023-01-31', 31, 'same month'
      include_examples 'valid date range processing', '2023-01-01', '2023-03-31', 90, 'multiple months'
      include_examples 'valid date range processing', '2023-01-15', '2023-01-15', 1, 'same start and end date'
      include_examples 'valid date range processing', '2023-02-01', '2023-03-01', 29, 'February across months (28 days + 1)'
    end

    context 'when handling leap year dates' do
      include_examples 'valid date range processing', '2024-01-01', '2024-01-31', 31, 'same month'
      include_examples 'valid date range processing', '2024-02-28', '2024-02-29', 2, 'February 29th included'
      include_examples 'valid date range processing', '2024-02-01', '2024-03-01', 30, 'February across months (29 days + 1)'
      include_examples 'valid date range processing', '2024-02-29', '2024-02-29', 1, 'Feb 29th as single day'
    end
  end

  describe 'authentication handling' do
    let(:mock_auth_manager) do
      instance_double('GoogleCalendarAuthManager').tap do |mock|
        allow(mock).to receive(:token_exist?).and_return(is_token_exist)
        allow(mock).to receive(:get_auth_url).and_return('https://accounts.google.com/oauth/authorize?...')
      end
    end

    let(:mock_token_manager) do
      instance_double('TokenManager').tap do |mock|
        allow(mock).to receive(:token_exist?).and_return(is_token_exist)
      end
    end

    let(:mock_calendar_repository) do
      instance_double('GoogleCalendarRepository').tap do |mock|
        allow(mock).to receive(:fetch_events).and_return(mock_events) if defined?(mock_events)
        allow(mock).to receive(:get_user_email).and_return('test@example.com')
      end
    end

    let(:mock_filter_service) do
      instance_double('EventFilterService').tap do |mock|
        allow(mock).to receive(:apply_filters).and_return(mock_events || [])
      end
    end

    let(:mock_analyzer_service) do
      instance_double('TimeAnalyzer').tap do |mock|
        allow(mock).to receive(:analyze).and_return({
          color_breakdown: {},
          summary: { total_hours: 0, total_events: 0 }
        })
      end
    end

    let(:server_context) {
      {
        auth_manager: mock_auth_manager,
        token_manager: mock_token_manager,
        calendar_repository: mock_calendar_repository,
        filter_service: mock_filter_service, # TODO:
        analyzer_service: mock_analyzer_service # TODO:
      }
    }

    include_examples 'BaseTool inheritance', InterfaceAdapters::AnalyzeCalendarTool, {
      start_date: "2024-01-01",
      end_date: "2024-01-31"
    }

    context 'when user is not authenticated' do
      let(:is_token_exist) { false }
      let(:mock_events) { [] }

      it 'should return authentication required message' do
        response = InterfaceAdapters::AnalyzeCalendarTool.call(
          start_date: "2024-01-01",
          end_date: "2024-01-31",
          server_context: server_context
        )
        content = JSON.parse(response.content[0][:text])

        aggregate_failures do
          expect(content['success']).to be false
          expect(content['error']).to include('認証が必要です')
          expect(content['auth_url']).to start_with('https://accounts.google.com')
        end
      end
    end

    context 'when user is authenticated' do
      include_context 'calendar analysis setup'
      let(:is_token_exist) { true }
      let(:mock_events) { [] }

      it 'should process calendar analysis successfully' do
        response = InterfaceAdapters::AnalyzeCalendarTool.call(
          start_date: "2024-01-01",
          end_date: "2024-01-31",
          server_context: server_context
        )
        content = JSON.parse(response.content[0][:text])

        aggregate_failures do
          expect(content['success']).to be true
          expect(content['summary']).to include('total_hours' => 0, 'total_events' => 0)
          expect(content['period']['start_date']).to eq('2024-01-01')
          expect(content['period']['end_date']).to eq('2024-01-31')
          expect(content['period']['days']).to eq(31)
          expect(content['analysis']).to eq({})
          expect(content['formatted_output']).to be_a(String)
        end
      end
    end
  end

  describe 'parameter validation' do
    it 'should handle missing required parameters' do
      init_req = initialize_request(0)
      invalid_req = {
        method: "tools/call",
        params: {
          name: "analyze_calendar_tool",
          arguments: {
            start_date: "2024-01-01"
          }
        },
        jsonrpc: "2.0",
        id: 1
      }
      responses = execute_mcp_requests([init_req, invalid_req])
      response = responses[1]

      expect(response).not_to be_nil
      expect(response['error']['code']).to eq(-32603)
      expect(response['error']['data']).to include('Missing required arguments: end_date')
    end

    describe 'date validation' do
      it 'should handle invalid date format' do
        init_req = initialize_request(0)
        analysis_req = analyze_calendar_request("invalid-date", "2024-01-31", 1)
        responses = execute_mcp_requests([init_req, analysis_req])
        response = responses[1]
        content = JSON.parse(response['result']['content'][0]['text'])

        expect(content['success']).to be false
        expect(content['error']).to include('invalid date')
      end

      it 'should handle end date before start date with authentication error' do
        init_req = initialize_request(0)
        analysis_req = analyze_calendar_request("2024-01-31", "2024-01-01", 1)
        responses = execute_mcp_requests([init_req, analysis_req])
        response = responses[1]

        # 日付論理エラーは認証エラーとして処理される
        expect(response['result']['isError']).to be false
        content = JSON.parse(response['result']['content'][0]['text'])
        expect(content['success']).to be false
        expect(content['error']).to include('認証が必要です')
      end
    end
  end

  describe 'color filtering' do
    include_context 'calendar analysis setup'

    before do
      # Override mock_filter to return has_filters: true for these tests
      mock_filter = instance_double('ColorFilterManager')
      allow(CalendarColorMCP::ColorFilterManager).to receive(:new).and_return(mock_filter)
      allow(mock_filter).to receive(:get_filtering_summary).and_return({ has_filters: true })
    end

    describe 'valid color specifications' do
      it 'should accept mixed color IDs and names' do
        response = InterfaceAdapters::AnalyzeCalendarTool.call(
          start_date: "2024-01-01",
          end_date: "2024-01-31",
          include_colors: [1, "緑", 3, "青"],
          server_context: server_context
        )
        content = JSON.parse(response.content[0][:text])

        expect(content['success']).to be true
        expect(content['period']['start_date']).to eq('2024-01-01')
        expect(content['period']['end_date']).to eq('2024-01-31')
      end

      it 'should handle both include and exclude parameters together' do
        response = InterfaceAdapters::AnalyzeCalendarTool.call(
          start_date: "2024-01-01",
          end_date: "2024-01-31",
          include_colors: [1, 2, "緑"],
          exclude_colors: [3, "赤"],
          server_context: server_context
        )
        content = JSON.parse(response.content[0][:text])

        expect(content['success']).to be true
        expect(content['period']['start_date']).to eq('2024-01-01')
        expect(content['period']['end_date']).to eq('2024-01-31')
      end
    end

    describe 'invalid color specifications' do
      it 'should reject invalid color IDs' do
        init_req = initialize_request(0)
        analysis_req = analyze_calendar_request("2024-01-01", "2024-01-31", 1, { include_colors: [0, 12, 15] })
        responses = execute_mcp_requests([init_req, analysis_req])
        response = responses[1]

        expect(response).to have_key('error')
        expect(response['error']['code']).to eq(-32603)
      end

      it 'should reject invalid color names' do
        init_req = initialize_request(0)
        analysis_req = analyze_calendar_request("2024-01-01", "2024-01-31", 1, { include_colors: ["無効な色", "存在しない色"] })
        responses = execute_mcp_requests([init_req, analysis_req])
        response = responses[1]

        expect(response).to have_key('error')
        expect(response['error']['code']).to eq(-32603)
      end
    end
  end

end
