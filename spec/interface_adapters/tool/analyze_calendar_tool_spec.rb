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
    let(:mock_use_case) { instance_double(Application::AnalyzeCalendarUseCase) }
    let(:mock_calendar_repository) { instance_double('MockCalendarRepository') }
    let(:mock_token_repository) { instance_double('MockTokenRepository') }
    let(:mock_oauth_service) { instance_double('MockOAuthService') }
    let(:server_context) { { oauth_service: mock_oauth_service, token_repository: mock_token_repository, calendar_repository: mock_calendar_repository } }

    include_examples 'BaseTool inheritance', InterfaceAdapters::AnalyzeCalendarTool, {
      start_date: "2024-01-01",
      end_date: "2024-01-31"
    }

    context 'when user is not authenticated' do
      before do
        allow(Application::AnalyzeCalendarUseCase).to receive(:new)
          .with(calendar_repository: mock_calendar_repository, token_repository: mock_token_repository)
          .and_return(mock_use_case)
        
        allow(mock_use_case).to receive(:execute)
          .and_raise(Application::AuthenticationRequiredError, "認証が必要です")
        
        allow(mock_oauth_service).to receive(:generate_auth_url)
          .and_return('https://accounts.google.com/oauth/authorize?...')
      end

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
      let(:mock_result) do
        {
          parsed_start_date: Date.parse("2024-01-01"),
          parsed_end_date: Date.parse("2024-01-31"),
          color_breakdown: {},
          summary: { 'total_hours' => 0, 'total_events' => 0 }
        }
      end

      before do
        allow(Application::AnalyzeCalendarUseCase).to receive(:new)
          .with(calendar_repository: mock_calendar_repository, token_repository: mock_token_repository)
          .and_return(mock_use_case)
        
        allow(mock_use_case).to receive(:execute)
          .with(
            start_date: "2024-01-01",
            end_date: "2024-01-31",
            include_colors: nil,
            exclude_colors: nil
          )
          .and_return(mock_result)
      end

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

      it 'should handle end date before start date with validation error' do
        init_req = initialize_request(0)
        analysis_req = analyze_calendar_request("2024-01-31", "2024-01-01", 1)
        responses = execute_mcp_requests([init_req, analysis_req])
        response = responses[1]

        # 日付バリデーションエラーが認証前に発生する（Use Case層での直接バリデーション）
        expect(response['result']['isError']).to be false
        content = JSON.parse(response['result']['content'][0]['text'])
        expect(content['success']).to be false
        expect(content['error']).to include('End date must be after start date')
      end
    end
  end

  describe 'color filtering' do
    include_context 'calendar analysis setup'

    before do
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
