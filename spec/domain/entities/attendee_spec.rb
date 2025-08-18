# frozen_string_literal: true

require_relative '../../spec_helper'

describe Domain::Attendee do
  let(:email) { 'test@example.com' }
  let(:response_status) { 'accepted' }
  let(:is_self) { false }

  subject(:attendee) do
    Domain::Attendee.new(
      email: email,
      response_status: response_status,
      self: is_self
    )
  end

  describe '#initialize' do
    it 'should initialize with provided attributes' do
      expect(attendee.email).to eq(email)
      expect(attendee.response_status).to eq(response_status)
      expect(attendee.self?).to eq(is_self)
    end
  end

  describe '#accepted?' do
    context 'when response_status is accepted' do
      let(:response_status) { 'accepted' }

      it 'should return true' do
        expect(attendee.accepted?).to be true
      end
    end

    context 'when response_status is not accepted' do
      let(:response_status) { 'declined' }

      it 'should return false' do
        expect(attendee.accepted?).to be false
      end
    end

    context 'when response_status is nil' do
      let(:response_status) { nil }

      it 'should return false' do
        expect(attendee.accepted?).to be false
      end
    end
  end

end