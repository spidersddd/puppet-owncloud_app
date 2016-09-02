# AO, Converting roles/profiles

This document is meant to give some overall guidance in porting Puppet Roles/Profiles to Puppet Application Orchestration layout.  While Roles/Profiles have been implemented in so many different ways and with many different guidance rules this will not be a howto.  

### What are Roles/Profiles

Roles/Profiles are simply Puppet modules that have wrapper classes inside.  They are meant to minimize complexity in a site.pp or classification tool.  Basically without roles/profiles node definitions would look something like:

```puppet
 # /etc/puppetlabs/puppet/manifests/site.pp
node /owncld\..*\.example\.com/ {
  include common
  class { '::owncloud':
   admin_pass    => 'puppetlabs',
   admin_user    => 'admin',
   db_host       => "owndb.${::env}.example.com",
   db_name       => 'owncloud',
   db_user       => 'owncloud',
   db_pass       => 'owncloud,
   db_if_connect => $::ipaddress_enp0s8,
  }
}
node "grover.example.com" {
  class { "ntp":
    servers    => [ 'kermit.example.com','0.us.pool.ntp.org iburst','1.us.pool.ntp.org iburst'],
    autoupdate => true,
    restrict   => [],
    enable     => true,
  }
}
```

When Roles/Profiles are created and utilized you end up with something like this in the site.pp:

```puppet
 # /etc/puppetlabs/puppet/manifests/site.pp
node /owncld\..*\.example\.com/ {
  include role::web::app
}
node "grover.example.com" {
  include profile::common
}
```

The Role level should be the top level of puppet wrapper classes, it should only include profiles and be several lines of 'include', 'include', etc.  Roles will look something like:

```puppet
class role::www_file_server {
  include profile::common
  include profile::security
  include profile::external_storage
  include profile::owncloud::web
}
```

The profile level is a more complex puppet class but still a wrapper class.  It will include component modules and some (limited) resource definitions.  They will be task specific and may use the technology in the name.  They should be generic and use hiera for the required configuration data.  Profiles may look something like:

```puppet
class profile::owncloud::web {
  $root_db_pass = hiera('profile::root_db_pass', 'owncloud')
  $db_host = hiera('profile::owncloud::db_server::db_host', "owndb.${::env}.example.com")
  $db_name = hiera('profile::owncloud::db_server::db_name', 'owncloud')
  $db_pass = hiera('profile::owncloud::db_server::db_pass', 'owncloud')
  $db_user = hiera('profile::owncloud::db_server::db_user', 'owncloud')
  $wb_port = hiera('profile::owncloud::wb_port', '8080')

  firewall { "100 allow http ${::hostname}":
    proto  => 'tcp',
    dport  => $wb_port,
    action => 'accept',
  } ->

  class { '::owncloud':
     admin_pass    => 'puppetlabs',
     admin_user    => 'admin',
     db_host       => $db_host,
     db_name       => $db_name,
     db_user       => $db_user,
     db_pass       => $db_pass,
     db_if_connect => $::ipaddress_enp0s8,
   }
}
```

### Application Orchestration Layout

With Application Orchestration (AO) the goal is to go the an even higher level then the Role layer.  The AO layer may replace the role layer and can continue to use the profile layer.  With the AO layer we define a stack of applications.  So rather than defining 'role::www\_file\_server' we would have a 'application' defined that will include the DB, and WWW\_File\_Server code and define the correlation between them.  This will allow Puppet to understand that the DB must be completed and exported before the web service will be able to function correctly.

Each application type, web for example, will be ported over as a defined type.  Defined types will allow Puppet to reuse the application code over and over again as new clusters/groups are classified.  With all that in mind some example code for the 'role::www\_file\_server' will look something like this as a defined type:

```puppet
 ##### Constructing the defined type
define owncloud_app::web (
  String $db_host,
  String $db_name,
  String $db_user,
  String $db_pass,
  String $interface = '',
  String $apache_port = '8080',
  Boolean $manage_db = false,
) {
  $admin_user = hiera('owncloud_app::web::admin_user', "admin-${::hostname}")
  $admin_pass = hiera('owncloud_app::web::admin_pass', "admin-${::hostname}")

  #### This will include some component modules and/or additional profiles
  include owncloud_app::web_profile

  $int =  $interface ? {
    /\S+/   => $::networking['interfaces'][$interface]['ip'],
    default => $::ipaddress }

  class { '::owncloud':
    admin_pass     => $admin_pass,
    admin_user     => $admin_user,
    db_host        => $db_host,
    db_name        => $db_name,
    db_user        => $db_user,
    db_pass        => $db_pass,
    manage_db      => $manage_db,
    http_port      => $apache_port,
    manage_apache  => true,
    db_if_connect  => $::ipaddress_enp0s8,
    require        => [
      Class['Mysql::Client'],
    ],
  }
}
 ###### closes the defined type
 ###### Setting some application specifics outside of defined type 
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
```

The included class 'owncloud\_app::web_profile':

```puppet
class owncloud_app::web_profile {
  firewall { "${apache_port} allow apache access":
    dport  => [$apache_port],
    proto  => tcp,
    action => accept,
  }
  include mysql::client
  include mysql::bindings
  include mysql::bindings::php
}
```
These application types (owncloud_app::web) should be called in from a Puppet defined 'application'.  This code is really the heart of Application Orchestration.  When defining an 'application' stack the code is very similar to normal code and syntax you will just be using the 'application' type rather than the 'class' or 'define' keyword.  Notice in the code below we have two components for this application, 'owncloud\_app::database' and 'owncloud\_app::web'.  The components are called from that app in a resource declaration and attributes are passed as expected.  

```puppet 
application owncloud_app (
  String $database        = 'owncloud',
  String $db_user         = 'owncloud',
  String $db_pass         = 'owncloud',
  String $web_int         = 'enp0s8',
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
}
```

### Things to note when converting Roles/Profile

1. Some of the configurations pulled from profiles will need to be ported as a defined type.
2. Each application type should have its own defined type.
3. Create a \<application\>/manifests/\<app type\>_profile that will help limit duplicate classes/resource if we are to stack (example owncloud\_app::database and owncloud\_app::web) on the same host.
4. Use functions from the [puppetlabs/app_modeling](https://forge.puppet.com/puppetlabs/app_modeling) to get hostname and titles of application teirs.


### AO classification

AO classification is done in the site.pp in a 'site' block.  In a site block applications are declared and tied to a specific host.  The application definition will tell puppet what order should be used for each application type, ie database before web.  The application name 'owncloud_app' is a direct call in puppet to '\<modulepath\>/owncloud\_app/manifests/init.pp'  Bellow is an example of what a site declaration would look like:

```puppet
site {

  owncloud_app { 'staging':
    web_int   => 'enp0s8',
    nodes     => {
       Node['owntest-appserver-01.pdx.puppet.vm']    => [
         Owncloud_app::Web['staging-0'],
       ],
       Node['owntest-appserver-02.pdx.puppet.vm']    => [
         Owncloud_app::Web['staging-1'],
       ],
      Node['owntest-database-01.pdx.puppet.vm']     => [
        Owncloud_app::Database['staging'],
      ],
    },
  }
}
```

Once an application has been added and module code available you will be able to use the puppet-job commands to view the assignment.  Example:

```
[root@master manifests]# puppet-app show
Owncloud_app[staging]
    Owncloud_app::Database[staging] => owntest-database-01.pdx.puppet.vm
      + produces Database[owndb-staging]
    Owncloud_app::Web[staging-1] => owntest-appserver-02.pdx.puppet.vm
      + produces Http[web-staging-1]
        consumes Database[owndb-staging]
    Owncloud_app::Web[staging-0] => owntest-appserver-01.pdx.puppet.vm
      + produces Http[web-staging-0]
        consumes Database[owndb-staging]
```
To deploy an application or changes to an application you use puppet-app as well.  Example:

```
[root@master manifests]# puppet-job run Owncloud_app['staging'] --concurrency 1
Starting deployment of Owncloud_app[staging] ...

+-------------------+-----------------------+
| Job ID            | 51                    |
| Target            | Owncloud_app[staging] |
| Concurrency Limit | 1                     |
| Nodes             | 3                     |
+-------------------+-----------------------+

Application instances: 1
  - Owncloud_app[staging]

Node run order (nodes in level 0 run before their dependent nodes in level 1, etc.):
0 -----------------------------------------------------------------------
owntest-database-01.pdx.puppet.vm
    Owncloud_app[staging] - Owncloud_app::Database[staging]

1 -----------------------------------------------------------------------
owntest-appserver-01.pdx.puppet.vm
    Owncloud_app[staging] - Owncloud_app::Web[staging-0]
owntest-appserver-02.pdx.puppet.vm
    Owncloud_app[staging] - Owncloud_app::Web[staging-1]

New job id created: 51
Started puppet run on owntest-database-01.pdx.puppet.vm ...
Finished puppet run on owntest-database-01.pdx.puppet.vm - Success!
    Applied configuration version 1472836815
    Resource events: 0 failed 0 changed 209 unchanged 0 skipped 0 noop
    Report: https://master.inf.puppet.vm/#/cm/report/f636b9432b4ee49d854b114e2acac4ec5b644468
Started puppet run on owntest-appserver-02.pdx.puppet.vm ...
Finished puppet run on owntest-appserver-02.pdx.puppet.vm - Success!
    Applied configuration version 1472836815
    Resource events: 0 failed 0 changed 353 unchanged 0 skipped 0 noop
    Report: https://master.inf.puppet.vm/#/cm/report/7b5c7ccab5135873b14ba10dc32f6f5540ad8d2e
Started puppet run on owntest-appserver-01.pdx.puppet.vm ...
Finished puppet run on owntest-appserver-01.pdx.puppet.vm - Success!
    Applied configuration version 1472836815
    Resource events: 0 failed 0 changed 353 unchanged 0 skipped 0 noop
    Report: https://master.inf.puppet.vm/#/cm/report/0f26be1813eca372628b3cf49bdf30a2ea71ea5e

Success! 3/3 runs succeeded.
Duration: 47 sec
```

To find more on AO please visit [Puppet Application Orchestration](https://docs.puppet.com/pe/latest/app_orchestration_overview.html).


