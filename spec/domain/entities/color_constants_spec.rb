require 'spec_helper'
require 'rspec-parameterized'
require_relative '../../../lib/calendar_color_mcp/domain/entities/color_constants'
require_relative '../../../lib/calendar_color_mcp/domain/errors'

RSpec.describe Domain::ColorConstants do

  describe '.name_to_id' do
    it 'returns the correct name to id mapping for English names' do
      expect(described_class.name_to_id['Peacock']).to eq(9)
      expect(described_class.name_to_id['Flamingo']).to eq(4)
      expect(described_class.name_to_id['Sage']).to eq(2)
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

  describe '.valid_color_id?' do
    where(:color_id, :expected) do
      [
        [0,   false], # 境界値: 最小値未満
        [1,   true],  # 境界値: 最小値
        [11,  true],  # 境界値: 最大値
        [12,  false], # 境界値: 最大値超過
        [nil, false]  # 無効な型
      ]
    end

    with_them do
      it 'validates color id correctly' do
        expect(described_class.valid_color_id?(color_id)).to eq(expected)
      end
    end
  end

  describe '.color_name' do
    subject { described_class.color_name(color_id) }

    where(:color_id, :expected) do
      [
        [1,   'Lavender'],
        [9,   'Peacock'],
        [11,  'Tomato'],
        [0,   nil],
        [12,  nil],
        [nil, nil]
      ]
    end

    with_them do
      it 'returns correct color name or nil' do
        is_expected.to eq(expected)
      end
    end
  end

  describe '.normalize_colors' do
    subject { described_class.normalize_colors(colors) }

    where(:colors, :expected, :description) do
      [
        [nil, [], 'nil input'],
        [[], [], 'empty array'],
        [[1, 2, 9, 11], ['1', '2', '9', '11'], 'valid integer color IDs'],
        [['Lavender', 'Sage', 'Peacock', 'Tomato'], ['1', '2', '9', '11'], 'valid English color names'],
        [['薄紫', '緑', '青', '濃い赤'], ['1', '2', '9', '11'], 'valid Japanese color names'],
        [['無効な色', '存在しない色'], [], 'invalid color names'],
        [[1, 'Sage', 9, '濃い赤', '無効な色'], ['1', '2', '9', '11'], 'mixed valid integers and both language color names'],
        [[1, 1.5, 'Sage'], ['1', '2'], 'mixed with Float values'],
        [[1, true, 'Sage'], ['1', '2'], 'mixed with Boolean values'],
        [[1, nil, 'Sage'], ['1', '2'], 'mixed with nil values'],
        [[0, 1, 12, 'Sage'], ['1', '2'], 'mixed with invalid color IDs'],
        [[0, 1, 1.5, 'Sage', true, nil, 12, 9], ['1', '2', '9'], 'mixed with all invalid types and values']
      ]
    end

    with_them do
      it 'normalizes colors correctly' do
        is_expected.to eq(expected)
      end
    end
  end
end
