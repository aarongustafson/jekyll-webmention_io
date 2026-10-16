# frozen_string_literal: true

require 'spec_helper'

describe Jekyll::WebmentionIO::BadUri do
  let(:checked_at) { '2026-10-15 19:54:00 -0600' }

  describe '#state' do
    it 'reads the state and attempt count from a cache entry' do
      entry = described_class.new('example.com', { 'state' => 'failure', 'attempts' => 3, 'last_checked' => checked_at })

      expect(entry.state).to eq('failure')
      expect(entry.attempts).to eq(3)
      expect(entry.last_check_date).to eq(Time.parse(checked_at))
    end

    it 'reads an older entry that holds only the check date' do
      entry = described_class.new('example.com', checked_at)

      expect(entry.state).to eq('unsupported')
      expect(entry.attempts).to eq(1)
      expect(entry.last_check_date).to eq(Time.parse(checked_at))
    end
  end

  describe 'a malformed check date' do
    it 'does not raise and leaves the check date unset' do
      entry = described_class.new('example.com', { 'state' => 'failure', 'attempts' => 1, 'last_checked' => 'not a date' })

      expect(entry.last_check_date).to be_nil
    end
  end

  describe '#to_val' do
    it 'writes the state and the attempt count back' do
      entry = described_class.new('example.com', { 'state' => 'error', 'attempts' => 2, 'last_checked' => checked_at })

      expect(entry.to_val).to include('state' => 'error', 'attempts' => 2)
    end

    it 'normalises an older entry into the shape the policy reads' do
      entry = described_class.new('example.com', checked_at)

      expect(entry.to_val).to include('state' => 'unsupported', 'attempts' => 1)
    end
  end
end
