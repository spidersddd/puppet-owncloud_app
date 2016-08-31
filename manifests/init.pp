application owncloud_app (
  String $database        = 'owncloud',
  String $db_user         = 'owncloud',
  String $db_pass         = 'owncloud',
  String $web_int         = '',
  String $web_port        = '8080',
#  String $lb_ipaddress    = '0.0.0.0',
#  String $lb_port         = '80',
#  String $lb_balance_mode = 'roundrobin',
#  Array  $lb_options      = ['forwardfor','http-server-close','httplog'],
){
  $db_components = collect_component_titles($nodes, Owncloud_app::Database)
  if (size($db_components) != 1) {
    $db_size = size($db_components)
    fail("There must be one database component for owncloud_app. found: ${db_size}")
  }
  owncloud_app::database { $db_components[0]:
    database => $database,
    user     => $db_user,
    password => $db_pass,
    export   => Database["owndb-${name}"]
  }

  # Collect the titles of all Web components declared in nodes.
  $web_components = collect_component_titles($nodes, Owncloud_app::Web)
  # Verify there is at least one web.
  if (size($web_components) == 0) {
    fail("Found no web component for Owncloud_app[${name}]. At least one is required")
  }
#  # For each of these declare the component and create an array of the exported
#  # Http resources from them for the load balancer.
#  $web_https = $web_components.map |$comp_name| {
#    # Compute the Http resource title for export and return.
#    $http = Http["web-${comp_name}"]
#    # Declare the web component.
#    owncloud_app::web { $comp_name:
#      apache_port => $web_port,
#      interface   => $web_int,
#      consume     => Database["owndb-${name}"],
#      export      => $http,
#    }
#    # Return the $http resource for the array.
#    $http
#  }

}
