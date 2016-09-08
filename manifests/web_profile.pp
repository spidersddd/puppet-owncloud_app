class owncloud_app::web_profile {

  include owncloud_app::ruby
  include mysql::client
  include mysql::bindings
  include mysql::bindings::php

}
