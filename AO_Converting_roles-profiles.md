#### Summary 

  1. [What are Roles/Profiles](#what-are-rolesprofiles)
    - [Example node classification in site.pp](#example-node-classification-in-sitepp)
    - [Example node classification with role/profile in site.pp](#example-node-classification-with-roleprofile-in-sitepp)
    - [Example Role](#section-id-50)
    - [Example profile](#section-id-62)
  2. [What is Application Orchestration Layout](#section-id-90)
    - [Example owncloud\_app::web_profile for AO](#section-id-152)
    - [Example AO application](#section-id-167)
  3. [Things to note when converting Roles/Profile](#section-id-229)
  4. [Application Orchestration classification](#section-id-238)
    - [Example AO site definition in site.pp](#section-id-242)
      - [Example puppet-app command](#section-id-268)
    - [Example puppet-job command](#section-id-287)
  5. [Additional Info](#section-id-343)
  



# AO, Converting roles/profiles

This document is meant to give some overall guidance in porting Puppet Roles/Profiles to Puppet Application Orchestration layout.  While Roles/Profiles have been implemented in so many different ways and with many different guidance rules this will not be a how to.  


### What are Roles/Profiles

Roles/Profiles are simply Puppet modules that have wrapper classes inside.  They are meant to minimize complexity in a site.pp or classification tool.  Basically without roles/profiles node definitions would look something like:


#### Example node classification in site.pp

```puppet
 # /etc/puppetlabs/puppet/manifests/site.pp
node /owntest\..*\.example\.com/ {
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


#### Example node classification with role/profile in site.pp
```puppet
 # /etc/puppetlabs/puppet/manifests/site.pp
node /owntest\..*\.example\.com/ {
  include role::web::app
}
node "grover.example.com" {
  include profile::common
}
```

The Role level should be the top level of puppet wrapper classes, it should only include profiles and be several lines of 'include', 'include', etc.  Roles will look something like:


#### Example Role
```puppet
class role::www_file_server {
  include profile::common
  include profile::security
  include profile::external_storage
  include profile::owncloud::web
}
```

The profile level is a more complex puppet class but still a wrapper class.  It will include component modules and some (limited) resource definitions.  They will be task specific and may use the technology in the name.  They should be generic and use hiera for the required configuration data.  Profiles may look something like:


#### Example profile
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

### What is Application Orchestration Layout

With Application Orchestration (AO) the goal is to go an even higher level then the Role layer.  The AO layer may replace the role layer and can continue to use the profile layer.  With the AO layer we define a stack of applications not just an individual.  So rather than defining 'role::www\_file\_server' we would have a 'application' defined that will include the WWW\_File\_Server, and the DB code define, as well as the dependency between them.  This will allows Puppet to understand that the DB must be completed and exported before the web service will be able to function correctly.

Each application type, www\_file\_server (owncloud_app::web) for example, will be ported over as a defined type.  Defined types will allow Puppet to reuse the application code over and over again in existing clusters as well as when new clusters/groups are classified.  With all that in mind some example code for the 'role::www\_file\_server' will look something like this as a defined type:

#### Example owncloud_app::web defined type for AO
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

```

The included class 'owncloud\_app::web_profile':


#### Example owncloud\_app::web_profile for AO
```puppet
class owncloud_app::web_profile {

  include owncloud_app::ruby
  include mysql::client
  include mysql::bindings
  include mysql::bindings::php

}
```
The application types (owncloud_app::web) should be called in from a Puppet defined 'application'.  This code is really the heart of Application Orchestration.  When defining an 'application' stack the code is very similar to normal code and syntax you will just be using the 'application' designation rather than the 'class' or 'define'.  Notice in the code below we have three components for this application, 'owncloud\_app::database' and 'owncloud\_app::web' and owncloud_app::lb.  The components are called from that app in a resource declaration and attributes are passed as expected.  


#### Example AO application 
```puppet 
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
```


### Things to note when converting Roles/Profile

1. Role will be replaced with application stack.
2. Some of the configurations pulled from profiles will need to be ported as a defined type.
3. Each application type may have its own defined type.
4. Create a \<application\>/manifests/\<app type\>_profile that will help limit duplicate classes/resource if we are to stack (example owncloud\_app::database and owncloud\_app::web) on the same host.
5. Use functions from the [puppetlabs/app_modeling](https://forge.puppet.com/puppetlabs/app_modeling) to get hostname and titles of application teirs.
6. Ensure ruby is installed on all hosts with consume services.


### Application Orchestration classification

AO classification is done in the site.pp in a 'site' block.  In a site block applications are declared and tied to a specific host.  The application definition will tell puppet what order should be used for each application type, ie database before web.  The application name 'owncloud_app' is a direct call in puppet to '\<modulepath\>/owncloud\_app/manifests/init.pp'  Bellow is an example of what a site declaration would look like:


#### Example AO site definition in site.pp
```puppet
site {

  owncloud_app { 'staging':
    web_int   => 'enp0s8',
    nodes     => {
       Node['owntest-loadbalancer-01.pdx.puppet.vm']     => [
        Owncloud_app::Lb['staging'],
      ],
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

Once an application has been added and application module code is available you will be able to use the puppet-app commands to view the assignment.  Example:


##### Example puppet-app command
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
    Owncloud_app::Lb[staging] => owntest-loadbalancer-01.pdx.puppet.vm
      + produces Http[lb-staging]
        consumes Http[web-staging-0]
        consumes Http[web-staging-1]
```
To deploy an application or changes to an application you use puppet-app as well.  Example:


#### Example puppet-job command
```
[root@master ~]# puppet-job run Owncloud_app['staging']
Starting deployment of Owncloud_app[staging] ...

+-------------------+-----------------------+
| Job ID            | 55                    |
| Target            | Owncloud_app[staging] |
| Concurrency Limit | None                  |
| Nodes             | 4                     |
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

2 -----------------------------------------------------------------------
owntest-loadbalancer-01.pdx.puppet.vm
    Owncloud_app[staging] - Owncloud_app::Lb[staging]

New job id created: 55
Started puppet run on owntest-database-01.pdx.puppet.vm ...
Finished puppet run on owntest-database-01.pdx.puppet.vm - Success!
    Applied configuration version 1473266409
    Resource events: 0 failed 0 changed 209 unchanged 0 skipped 0 noop
    Report: https://master.inf.puppet.vm/#/cm/report/b04480c5ab809c1520d3dbca54dcbf777ef8acbd
Started puppet run on owntest-appserver-02.pdx.puppet.vm ...
Started puppet run on owntest-appserver-01.pdx.puppet.vm ...
Finished puppet run on owntest-appserver-01.pdx.puppet.vm - Success!
    Applied configuration version 1473266409
    Resource events: 0 failed 1 changed 352 unchanged 0 skipped 0 noop
    Report: https://master.inf.puppet.vm/#/cm/report/9d89b938e48f4db8b654a940082c41416663a7f1
Finished puppet run on owntest-appserver-02.pdx.puppet.vm - Success!
    Applied configuration version 1473266409
    Resource events: 0 failed 1 changed 352 unchanged 0 skipped 0 noop
    Report: https://master.inf.puppet.vm/#/cm/report/4d2cc6b05e61dafc5cecd48f4f2792def7e94d42
Started puppet run on owntest-loadbalancer-01.pdx.puppet.vm ...
Finished puppet run on owntest-loadbalancer-01.pdx.puppet.vm - Success!
    Applied configuration version 1473266409
    Resource events: 0 failed 0 changed 219 unchanged 0 skipped 0 noop
    Report: https://master.inf.puppet.vm/#/cm/report/9c4d171b4b2bf91f8a90d2e2297389ea62c0d1fb

Success! 4/4 runs succeeded.
Duration: 47 sec
```


### Additional Info

To find more on AO please visit [Puppet Application Orchestration](https://docs.puppet.com/pe/latest/app_orchestration_overview.html).

Example Wordpress application [Puppet Forge Wordpress Module](https://forge.puppet.com/puppetlabs/wordpress_app)

