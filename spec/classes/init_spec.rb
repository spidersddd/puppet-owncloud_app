require 'spec_helper'
describe 'owncloud_app' do

  context 'with defaults for all parameters' do
    it { should contain_class('owncloud_app') }
  end
end
