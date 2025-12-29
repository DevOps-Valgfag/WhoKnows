# spec/unit/security_spec.rb
require 'spec_helper'

RSpec.describe 'Security helpers' do
  describe '#hash_password and #verify_password' do
    it 'hashes and verifies a password' do
      password = 'super-secret'
      hashed   = hash_password(password)

      # Hash should not equal the plain text
      expect(hashed.to_s).not_to eq(password)

      # And verify_password should accept the stored hash string
      expect(verify_password(hashed.to_s, password)).to be true
    end

    it 'returns false for an invalid stored hash' do
      expect(verify_password('not-a-valid-hash', 'whatever')).to be false
    end
  end
end
