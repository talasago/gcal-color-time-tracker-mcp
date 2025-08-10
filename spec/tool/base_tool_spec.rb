require 'spec_helper'
require_relative '../../lib/calendar_color_mcp/tools/base_tool'

RSpec.describe CalendarColorMCP::BaseTool do
  let(:auth_manager) { double('auth_manager') }
  let(:server_context) { { auth_manager: auth_manager } }
  let(:context) { { server_context: server_context } }

  describe '.extract_auth_manager' do
    subject { described_class.send(:extract_auth_manager, context) }

    context 'when server_context contains auth_manager' do
      it { is_expected.to eq(auth_manager) }
    end

    context 'when server_context is nil' do
      let(:context) { { server_context: nil } }
      it { expect { subject }.to raise_error(ArgumentError, "認証マネージャーが利用できません") }
    end

    context 'when auth_manager is nil' do
      let(:server_context) { { auth_manager: nil } }
      it { expect { subject }.to raise_error(ArgumentError, "認証マネージャーが利用できません") }
    end

    context 'when server_context is missing' do
      let(:context) { {} }
      it { expect { subject }.to raise_error(ArgumentError, "認証マネージャーが利用できません") }
    end
  end

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
    it { is_expected.to be_a(CalendarColorMCP::BaseTool::ErrorResponseBuilder) }
  end

  describe CalendarColorMCP::BaseTool::ErrorResponseBuilder do
    let(:message) { "test error message" }
    let(:builder) { described_class.new(message) }

    describe '#build' do
      subject { builder.build }
      let(:parsed_json) { JSON.parse(subject.content[0][:text]) }

      context 'with initial message only' do
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
          expect(parsed_json).to eq({ 'success' => false, 'error' => message })
        end
      end

      context 'when chained with #with' do
        subject { builder.with(:auth_url, "https://example.com").build }

        it 'includes additional data in response' do
          expect(parsed_json).to include(
            'success' => false, 
            'error' => message, 
            'auth_url' => 'https://example.com'
          )
        end
      end
    end

    describe '#with' do
      let(:response) { builder.build }
      let(:parsed_json) { JSON.parse(response.content[0][:text]) }

      context 'when given key-value pair' do
        subject { builder.with(:auth_url, "https://example.com") }

        it 'returns self for method chaining' do
          expect(subject).to eq(builder)
        end

        it 'adds data to builder' do
          subject
          expect(parsed_json).to include('auth_url' => 'https://example.com')
        end
      end

      context 'when given hash as first argument' do
        let(:data_hash) { { auth_url: "https://example.com", code: "123" } }

        it 'merges hash data into builder' do
          builder.with(data_hash)
          expect(parsed_json).to include(
            'auth_url' => 'https://example.com',
            'code' => '123'
          )
        end
      end

      context 'when given keyword arguments' do
        it 'merges keyword data into builder' do
          builder.with(:dummy, nil, auth_url: "https://example.com", code: "123")
          expect(parsed_json).to include(
            'auth_url' => 'https://example.com',
            'code' => '123'
          )
        end
      end
    end

    describe '#add' do
      let(:add_builder) { described_class.new("test") }
      let(:with_builder) { described_class.new("test") }

      it 'behaves the same as #with method' do
        add_builder.add(:key, "value")
        with_builder.with(:key, "value")

        expect(JSON.parse(add_builder.build.content[0][:text])).to eq(
          JSON.parse(with_builder.build.content[0][:text])
        )
      end
    end

    describe 'method chaining' do
      subject do
        builder
          .with(:auth_url, "https://example.com")
          .add(:code, "123")
          .with(:status, "pending")
          .build
      end

      let(:parsed_json) { JSON.parse(subject.content[0][:text]) }

      it 'supports fluent interface with multiple method calls' do
        expect(parsed_json).to include(
          'success' => false,
          'error' => message,
          'auth_url' => 'https://example.com',
          'code' => '123',
          'status' => 'pending'
        )
      end
    end
  end
end
