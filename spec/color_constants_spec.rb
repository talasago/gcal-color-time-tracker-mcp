require 'spec_helper'
require_relative '../lib/calendar_color_mcp/color_constants'

RSpec.describe CalendarColorMCP::ColorConstants do

  describe '.name_to_id' do
    it 'returns the correct name to id mapping' do
      expect(described_class.name_to_id['青']).to eq(9)
      expect(described_class.name_to_id['赤']).to eq(4)
      expect(described_class.name_to_id['緑']).to eq(2)
    end

    it 'returns a frozen hash' do
      expect(described_class.name_to_id).to be_frozen
    end
  end

  describe '.default_color_id' do
    it 'returns 9 (blue) as default' do
      expect(described_class.default_color_id).to eq(9)
    end
  end

  describe '.color_names_array' do
    it 'returns an array of color names' do
      expected_names = ['薄紫', '緑', '紫', '赤', '黄', 'オレンジ', '水色', '灰色', '青', '濃い緑', '濃い赤']
      
      expect(described_class.color_names_array).to match_array(expected_names)
    end
  end

  describe '.valid_color_id?' do
    context 'with valid color id' do
      it 'returns true for id 1-11' do
        (1..11).each do |id|
          expect(described_class.valid_color_id?(id)).to be true
        end
      end
    end

    context 'with invalid color id' do
      it 'returns false for id 0' do
        expect(described_class.valid_color_id?(0)).to be false
      end

      it 'returns false for id 12' do
        expect(described_class.valid_color_id?(12)).to be false
      end

      it 'returns false for nil' do
        expect(described_class.valid_color_id?(nil)).to be false
      end
    end
  end

  describe '.color_name' do
    context 'with valid color id' do
      it 'returns the correct color name' do
        expect(described_class.color_name(1)).to eq('薄紫')
        expect(described_class.color_name(9)).to eq('青')
        expect(described_class.color_name(11)).to eq('濃い赤')
      end
    end

    context 'with invalid color id' do
      it 'returns nil' do
        expect(described_class.color_name(0)).to be_nil
        expect(described_class.color_name(12)).to be_nil
        expect(described_class.color_name(nil)).to be_nil
      end
    end
  end
end