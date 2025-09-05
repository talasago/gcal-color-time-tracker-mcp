require 'spec_helper'
require_relative '../../../lib/calendar_color_mcp/interface_adapters/tools/base_tool'

RSpec.describe InterfaceAdapters::BaseTool do
  let(:server_context) { {} }
  let(:context) { { server_context: server_context } }

  describe '.success_response' do
    subject { described_class.send(:success_response, data) }
    let(:parsed_json) { JSON.parse(subject.content[0][:text]) }

    context 'when given data hash' do
      let(:data) { { message: "test", value: 42 } }

      it { is_expected.to be_a(MCP::Tool::Response) }
      it { expect(subject.content.length).to eq(1) }
      it { expect(subject.content[0][:type]).to eq("text") }
      it { expect(parsed_json).to include('success' => true, 'message' => 'test', 'value' => 42) }
    end

    context 'when given empty data' do
      let(:data) { {} }
      it { expect(parsed_json).to eq({ 'success' => true }) }
    end
  end

  describe '.error_response' do
    subject { described_class.send(:error_response, "test error") }
    let(:parsed_json) { JSON.parse(subject.content[0][:text]) }

    it 'returns MCP::Tool::Response instance' do
      expect(subject).to be_a(MCP::Tool::Response)
    end

    it 'contains single content item' do
      expect(subject.content.length).to eq(1)
    end

    it 'has text type content' do
      expect(subject.content[0][:type]).to eq("text")
    end

    it 'includes error message in JSON format' do
      expect(parsed_json).to eq({ 'success' => false, 'error' => 'test error' })
    end

    context 'when given additional data' do
      subject { described_class.send(:error_response, "test error", auth_url: "https://example.com", code: "123") }

      it 'includes additional data in response' do
        expect(parsed_json).to include(
          'success' => false,
          'error' => 'test error',
          'auth_url' => 'https://example.com',
          'code' => '123'
        )
      end
    end
  end
end
