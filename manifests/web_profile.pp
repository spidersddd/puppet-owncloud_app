class owncloud_app::web_profile {

  include wordpress_app::ruby
  include mysql::client
  include mysql::bindings
  include mysql::bindings::php

}
