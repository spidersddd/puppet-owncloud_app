class owncloud_app::ruby (
  $manage = true,
) {
  if $manage {
    package{'ruby':
      ensure => 'present',
    }
  }
}
