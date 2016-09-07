application owncloud_app (
  String $database        = 'owncloud',
  String $db_user         = 'owncloud',
  String $db_pass         = 'owncloud',
  String $web_int         = 'enp0s8',
  String $lb_ipaddress    = '0.0.0.0',
  String $lb_port         = '80',
  String $lb_balance_mode = 'roundrobin',
  Array  $lb_options      = ['forwardfor','http-server-close','httplog'],
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

  # Collect the node name of the Owncloud_app::Database
  $db_hostname = collect_component_nodes($nodes, Owncloud_app::Database)
  # Collect the titles of all Web components declared in nodes.
  $web_components = collect_component_titles($nodes, Owncloud_app::Web)
  # Verify there is at least one web.
  if (size($web_components) == 0) {
    fail("Found no web component for Owncloud_app[${name}]. At least one is required")
  }
  # For each of these declare the component and create an array of the exported
  # Http resources from them for the load balancer.
  $web_https = $web_components.map |$comp_name| {
    # Compute the Http resource title for export and return.
    $http = Http["web-${comp_name}"]
    # Declare the web component.
    owncloud_app::web { $comp_name:
      db_host   => $db_hostname[0],
      db_name   => $database,
      db_pass   => $db_pass,
      db_user   => $db_user,
      interface => $web_int,
      consume   => Database["owndb-${name}"],
      export    => $http,
    }
    # Return the $http resource for the array.
    $http
  }
  # Create an lb component for each declared load balancer.
  $lb_components = collect_component_titles($nodes, Owncloud_app::Lb)
  $lb_components.each |$comp_name| {
    owncloud_app::lb { $comp_name:
      balancermembers => $web_https,
      lb_options      => $lb_options,
      ipaddress       => $lb_ipaddress,
      port            => $lb_port,
      balance_mode    => $lb_balance_mode,
      require         => $web_https,
      export          => Http["lb-${name}"],
    }
  }
}
