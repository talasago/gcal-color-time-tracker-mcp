require 'spec_helper'
require 'json'
require 'open3'

RSpec.describe 'Calendar Flow Integration', type: :integration do
  let(:server_command) { './bin/calendar-color-mcp' }
  let(:timeout_duration) { 5 }

  def execute_mcp_requests(requests)
    requests_json = requests.map(&:to_json).join("\n")

    stdout, stderr, status = Open3.capture3(
      "echo '#{requests_json}' | timeout #{timeout_duration} #{server_command}"
    )

    begin
      responses = stdout.strip.split("\n").map { |line| JSON.parse(line) }
    rescue JSON::ParserError => e
      puts "stdout: #{stdout}"
      puts "stderr: #{stderr}"
      raise "Failed to parse JSON responses: #{e.message}"
    end

    responses
  end

  describe 'calendar analysis authentication patterns' do
    # NOTE: Test case for 'when user has valid authentication token' is not implemented
    #
    # Reason: Cannot automatically generate valid Google Calendar API tokens for testing
    #
    # To test this scenario manually:
    # 1. Obtain valid OAuth credentials from Google Cloud Console
    # 2. Complete the actual authentication flow to generate token.json
    # 3. Run tests with the valid token.json file present

    context 'when user has no authentication token' do
      before do
        # Remove token file to simulate no authentication
        File.delete('token.json') if File.exist?('token.json')
      end

      after do
        # Clean up - ensure token file is removed after test
        File.delete('token.json') if File.exist?('token.json')
      end

      it 'returns authentication error when analyzing calendar' do
        requests = [
          initialize_request(0),
          check_auth_status_request(1),
          analyze_calendar_request("2024-01-01", "2024-01-31", 2)
        ]

        responses = execute_mcp_requests(requests)

        aggregate_failures do
          expect(responses.length).to eq(3)

          # Initialize response
          expect(responses[0]['result']['serverInfo']['name']).to eq('calendar-color-analytics')

          # Auth status should show not authenticated
          auth_status_content = JSON.parse(responses[1]['result']['content'][0]['text'])
          expect(auth_status_content['authenticated']).to be false

          # Analysis should indicate authentication is required
          analysis_response = responses[2]
          expect(analysis_response['result']['isError']).to be false
          analysis_content = JSON.parse(analysis_response['result']['content'][0]['text'])

          # Should indicate failure due to authentication
          if analysis_content.has_key?('success')
            expect(analysis_content['success']).to be false
          end

          # Should contain auth-related error message
          error_message = analysis_content['error'] || analysis_content['message'] || analysis_content['description']
          expect(error_message).to be_a(String)
          expect(error_message).to include('認証').or include('authentication')
        end
      end

      it 'completes full authentication flow and then analyzes calendar' do
        requests = [
          initialize_request(0),
          check_auth_status_request(1),
          start_auth_request(2),
          complete_auth_request("invalid_test_code", 3),
          analyze_calendar_request("2024-01-01", "2024-01-31", 4)
        ]

        responses = execute_mcp_requests(requests)

        aggregate_failures do
          expect(responses.length).to eq(5)

          # Auth status should initially show not authenticated
          auth_status_content = JSON.parse(responses[1]['result']['content'][0]['text'])
          expect(auth_status_content['authenticated']).to be false

          # Start auth should succeed
          start_auth_content = JSON.parse(responses[2]['result']['content'][0]['text'])
          expect(start_auth_content['success']).to be true
          expect(start_auth_content).to have_key('auth_url')

          # Complete auth should fail with invalid code
          complete_auth_content = JSON.parse(responses[3]['result']['content'][0]['text'])
          expect(complete_auth_content['success']).to be false

          # Analysis should still require authentication
          analysis_content = JSON.parse(responses[4]['result']['content'][0]['text'])
          if analysis_content.has_key?('success')
            expect(analysis_content['success']).to be false
          end
          error_message = analysis_content['error'] || analysis_content['message'] || analysis_content['description']
          expect(error_message).to include('認証').or include('authentication')
        end
      end
    end

    context 'when user has expired authentication token' do
      before do
        # Create an expired token for this test
        expired_token = {
          'access_token' => 'expired_access_token',
          'refresh_token' => 'test_refresh_token',
          'expires_at' => Time.now.to_i - 3600  # Expired 1 hour ago
        }
        File.write('token.json', expired_token.to_json)
      end

      after do
        # Clean up token file
        File.delete('token.json') if File.exist?('token.json')
      end

      it 'returns authentication error due to expired token' do
        requests = [
          initialize_request(0),
          check_auth_status_request(1),
          analyze_calendar_request("2024-01-01", "2024-01-31", 2)
        ]

        responses = execute_mcp_requests(requests)

        aggregate_failures do
          expect(responses.length).to eq(3)

          # Initialize response
          expect(responses[0]['result']['serverInfo']['name']).to eq('calendar-color-analytics')

          # Auth status might show not authenticated or indicate token issues
          auth_status_content = JSON.parse(responses[1]['result']['content'][0]['text'])
          expect(auth_status_content).to have_key('authenticated')

          # Analysis should fail due to expired token
          analysis_response = responses[2]
          expect(analysis_response['result']['isError']).to be false
          analysis_content = JSON.parse(analysis_response['result']['content'][0]['text'])

          # Should indicate failure
          if analysis_content.has_key?('success')
            expect(analysis_content['success']).to be false
          end

          # Should contain auth-related or token expiry error message
          error_message = analysis_content['error'] || analysis_content['message'] || analysis_content['description']
          expect(error_message).to be_a(String)
          expect(error_message).to include('認証').or include('authentication').or include('expired').or include('期限').or include('Authorization failed')
        end
      end

      it 'completes re-authentication flow from expired token state' do
        requests = [
          initialize_request(0),
          check_auth_status_request(1),
          start_auth_request(2),
          analyze_calendar_request("2024-01-01", "2024-01-31", 3),
          complete_auth_request("invalid_reauth_code", 4)
        ]

        responses = execute_mcp_requests(requests)

        aggregate_failures do
          expect(responses.length).to eq(5)

          # Auth status response
          auth_status_content = JSON.parse(responses[1]['result']['content'][0]['text'])
          expect(auth_status_content).to have_key('authenticated')

          # Start auth should succeed even with expired token
          start_auth_content = JSON.parse(responses[2]['result']['content'][0]['text'])
          expect(start_auth_content['success']).to be true
          expect(start_auth_content).to have_key('auth_url')

          # Analysis should still fail before auth completion
          analysis_content = JSON.parse(responses[3]['result']['content'][0]['text'])
          if analysis_content.has_key?('success')
            expect(analysis_content['success']).to be false
          end

          # Complete auth should fail with invalid code
          complete_auth_content = JSON.parse(responses[4]['result']['content'][0]['text'])
          expect(complete_auth_content['success']).to be false
        end
      end
    end
  end
end
