RSpec.shared_examples 'valid MCP protocol response' do
  it 'returns valid MCP protocol response' do
    aggregate_failures do
      expect(response['jsonrpc']).to eq('2.0')
      expect(response['id']).to eq(expected_id)
      expect(response['result']['isError']).to be false
      expect(response['result']['content']).to be_an(Array)
      expect(response['result']['content'].length).to eq(1)
    end
  end
end

RSpec.shared_examples 'handles invalid parameters gracefully' do |tool_name|
  it 'should handle tool call with invalid parameters gracefully' do
    init_req = initialize_request(0)
    invalid_req = {
      method: "tools/call",
      params: {
        name: tool_name,
        arguments: {
          invalid_param: "should_be_ignored"
        }
      },
      jsonrpc: "2.0",
      id: 1
    }
    responses = execute_mcp_requests([init_req, invalid_req])
    response = responses[1]

    expect(response['result']['isError']).to be false
    content = JSON.parse(response['result']['content'][0]['text'])
    expect(content['success']).to be true
  end
end

RSpec.shared_examples 'handles missing auth manager' do |tool_class|
  context 'when auth_manager is not available' do
    it 'should return error response' do
      response = tool_class.call(server_context: {})
      content = JSON.parse(response.content[0][:text])

      aggregate_failures do
        expect(content['success']).to be false
        expect(content['error']).to eq('認証マネージャーが利用できません')
      end
    end
  end
end

module MCPSharedHelpers
  def expect_mcp_protocol_response(response, expected_id)
    aggregate_failures do
      expect(response['jsonrpc']).to eq('2.0')
      expect(response['id']).to eq(expected_id)
      expect(response['result']['isError']).to be false
      expect(response['result']['content']).to be_an(Array)
      expect(response['result']['content'].length).to eq(1)
    end
  end

  def expect_success_response(content)
    expect(content).to have_key('success')
    expect([true, false]).to include(content['success'])
  end

  def parse_response_content(response)
    JSON.parse(response['result']['content'][0]['text'])
  end
end