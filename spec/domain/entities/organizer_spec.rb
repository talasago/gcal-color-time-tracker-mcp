# frozen_string_literal: true

require_relative '../../spec_helper'

describe Domain::Organizer do
  let(:email) { 'organizer@example.com' }
  let(:display_name) { 'Test Organizer' }
  let(:is_self) { false }

  subject(:organizer) do
    Domain::Organizer.new(
      email: email,
      display_name: display_name,
      self: is_self
    )
  end

  describe '#initialize' do
    it 'should initialize with provided attributes' do
      expect(organizer.email).to eq(email)
      expect(organizer.display_name).to eq(display_name)
      expect(organizer.self?).to eq(is_self)
    end

    context 'when display_name is not provided' do
      subject(:organizer) do
        Domain::Organizer.new(
          email: email,
          self: is_self
        )
      end

      it 'should initialize with nil display_name' do
        expect(organizer.email).to eq(email)
        expect(organizer.display_name).to be_nil
        expect(organizer.self?).to eq(is_self)
      end
    end

    context 'when self is not provided' do
      subject(:organizer) do
        Domain::Organizer.new(
          email: email,
          display_name: display_name
        )
      end

      it 'should default self to false' do
        expect(organizer.email).to eq(email)
        expect(organizer.display_name).to eq(display_name)
        expect(organizer.self?).to be false
      end
    end
  end

  describe '#self?' do
    context 'when self is true' do
      let(:is_self) { true }

      it 'should return true' do
        expect(organizer.self?).to be true
      end
    end

    context 'when self is false' do
      let(:is_self) { false }

      it 'should return false' do
        expect(organizer.self?).to be false
      end
    end
  end

  describe '#display_name_or_email' do
    context 'when display_name is present' do
      let(:display_name) { 'Test Organizer' }

      it 'should return display_name' do
        expect(organizer.display_name_or_email).to eq(display_name)
      end
    end

    context 'when display_name is nil' do
      let(:display_name) { nil }

      it 'should return email' do
        expect(organizer.display_name_or_email).to eq(email)
      end
    end

    context 'when display_name is empty string' do
      let(:display_name) { '' }

      it 'should return email' do
        expect(organizer.display_name_or_email).to eq(email)
      end
    end
  end
end