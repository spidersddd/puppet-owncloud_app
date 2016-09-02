class owncloud_app::web_profile {

  include mysql::client
  include mysql::bindings
  include mysql::bindings::php

}
