class owncloud_app::web_profile {
  firewall { "100 allow http ${::hostname}":
    proto  => 'tcp',
    dport  => '80',
    action => 'accept',
  }

  #  include apache::mod::php
  include mysql::client
  include mysql::bindings
  include mysql::bindings::php

}
