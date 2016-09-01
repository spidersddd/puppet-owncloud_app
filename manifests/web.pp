define owncloud_app::web (
  String $db_host,
  String $db_name,
  String $db_user,
  String $db_pass,
  String $interface = '',
  String $apache_port = '8080',
  Boolean $manage_db = false,
) {
  include owncloud_app::web_profile
  include apache::mod::php
  include mysql::client
  include mysql::bindings
  include mysql::bindings::php

  $int =  $interface ? {
    /\S+/   => $::networking['interfaces'][$interface]['ip'],
    default => $::ipaddress }

#  apache::vhost { $::fqdn:
#    priority   => '10',
#    vhost_name => $::fqdn,
#    port       => $apache_port,
#    docroot    => '/var/www/html',
#    ip         => $int,
#  } ->

  class { '::owncloud':
    admin_pass     => 'puppetlabs',
    admin_user     => 'admin',
    db_host        => $db_host,
    db_name        => $db_name,
    db_user        => $db_user,
    db_pass        => $db_pass,
    manage_db      => $manage_db,
    http_port      => $apache_port,
#    manage_apache => false,
    db_if_connect  => $::ipaddress_enp0s8,
    require        => [
      Class['Mysql::Client'],
    ],
  }

  firewall { "${apache_port} allow apache access":
    dport  => [$apache_port],
    proto  => tcp,
    action => accept,
  }
}
Owncloud_app::Web consumes Database{
  db_host     => $host,
  db_name     => $database,
  db_user     => $user,
  db_password => $password,
}
Owncloud_app::Web produces Http {
  ip   => $interface ? { /\S+/ => $::networking['interfaces'][$interface]['ip'], default => $::ipaddress },
  port => $apache_port,
  host => $::hostname,
  status_codes => [200, 302],
}
