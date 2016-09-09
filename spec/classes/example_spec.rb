require 'spec_helper'

describe 'owncloud_app' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts
        end

        context "owncloud_app class without any parameters" do
          it { is_expected.to compile.with_all_deps }

          it { is_expected.to contain_class('owncloud_app::params') }
          it { is_expected.to contain_class('owncloud_app::install').that_comes_before('owncloud_app::config') }
          it { is_expected.to contain_class('owncloud_app::config') }
          it { is_expected.to contain_class('owncloud_app::service').that_subscribes_to('owncloud_app::config') }

          it { is_expected.to contain_service('owncloud_app') }
          it { is_expected.to contain_package('owncloud_app').with_ensure('present') }
        end
      end
    end
  end

  context 'unsupported operating system' do
    describe 'owncloud_app class without any parameters on Solaris/Nexenta' do
      let(:facts) do
        {
          :osfamily        => 'Solaris',
          :operatingsystem => 'Nexenta',
        }
      end

      it { expect { is_expected.to contain_package('owncloud_app') }.to raise_error(Puppet::Error, /Nexenta not supported/) }
    end
  end
end
