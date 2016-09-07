# owncloud_app

## Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with owncloud_app](#setup)
    * [What [modulename] affects](#what-[modulename]-affects)
        * [Setup requirements](#setup-requirements)
            * [Beginning with [modulename]](#beginning-with-[modulename])
            3. [Usage - Configuration options and additional functionality](#usage)
            4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
            5. [Limitations - OS compatibility, etc.](#limitations)

## Description

The Puppet owncloud_app is a module that demonstrates an example application model. The module contains application components you can use to set up a Owncloud database and a Owncloud application server. With these components, you can build an Owncloud application stack.

## Setup Requirements

To use this module, you must enable application management on the Puppet master. Add `app_management = true` to the `puppet.conf` file on your Puppet master. You also need to enable plugin sync on any agents that will host application components.

If you use Puppet Enterprise, the [Puppet orchestrator documentation](https://docs.puppet.com/pe/latest/orchestrator_intro.html) provides commands and API endpoints you can use to deploy the owncloud_app.

In addition, see the [application orchestration workflow](https://docs.puppet.com/pe/latest/app_orchestration_workflow.html) docs for more conceptual information.

If you use r10k, this module includes a `Puppetfile` that will install the module and its dependencies.

## Beginning with owncloud_app

### SELinux

SELinux may prevent Apache from connecting to MySQL. Make sure it's properly
configured or disabled if you run into database connection errors.

## Patterns

### `owncloud_app`

It uses functions to dynamically discover what components have been declared, and then it validates and connects them. You should use this type of definition if you have a varying number of components, or if some components are optional. By discovering the component names dynamically, you don't have to worry about matching statically declared component names.

In the following example, the `collect_component_titles` function searches through the application's nodes and finds all resources matching a certain component type and returns a list of their titles. The function verifies that there is one database, and it then declares that resource. Since the name of the exported database capability resource is set for internal consumption, you shouldn't have to track the name.

```puppet
  $db_components = collect_component_titles($nodes, Owncloud_app::Database)
  if (size($db_components) != 1){
    $db_size = size($db_components)
    fail("There must be one database component for owncloud_app. found: ${db_size}")
  }
  owncloud_app::database { $db_components[0]:
    database   => $database,
    user       => $db_user,
    password   => $db_pass,
    export     => Database["wdp-${name}"]
  }
```
For the web components, the function collects all resources assigned to nodes in the application and collects the database hostname to be used by the owncloud configuration. The map function loops over the resources and declares the components, and it then collects the HTTP resources they export for later consumption. This allows you to declare one or more web components to scale your application dynamically through the declaration.  For owncloud_app:web hosts to have the same files the server will need some type of shared storage mounted for the owncloud data directory.

For example:

```puppet
  $web_components = collect_component_titles($nodes, Owncloud_app::Web)
  # Verify there is at least one Web.
  if (size($web_components) == 0) {
    fail("Found no web component for Owncloud_app[${name}]. At least one is required")
  }
  # For each of these, declare the component and create an array of the exported
  # Http resources from them for the load balancer.
  $web_https = $web_components.map |$comp_name| {
    # Compute the Http resource title for export and return.
    $http = Http["web-$comp_name"]
    # Declare the web component.
    owncloud_app::web { $comp_name:
      apache_port => $web_port,
      interface   => $web_int,
      consume     => Database["wdp-${name}"],
      export      => $http,
    }
    # Return the $http resource for the array.
    $http
  }
```

The following example shows a declaration of an instance of the Owncloud application with two web nodes. The resource titles used here are arbitrary, but they must be unique in this environment.

```puppet
  owncloud_app { 'tiered':
    nodes => {
      # The titles of these don't matter as long as they're unique per component.
      Node['node1.example.com'] => Owncloud_app::Database['owncloud-db'],
      Node['node3.example.com'] => Owncloud_app::Web['tiered-web01'],
      Node['node4.example.com'] => Owncloud_app::Web['owncloud-web02'],
    }
  }
```

### Components vs Profiles

If you're already organizing your code into *roles and profiles*, the application components are probably very similiar to your profiles. If all your nodes serve a single purpose, you may be able to just convert your profile classes into component defined types. However, if you need to put multiple components on a single node that share resources, this may result in conflicts. For example, if you have one database node that provides databases for multiple Owncloud application instances, MySQL resources may be shared. Or, if you have multiple HTTP components in your stack, Apache resources might be shared. If this is the case, you should turn the components into profile classes that can then be included in the component. Consider `owncloud_app:database` and `workpress_app::database_profile`: the underlying MySQL server and firewall rules are configured in the profile while the specific datbase, user, and permissions are managed in the component.

## Reference

### Applications

#### `owncloud_app`

Using the `collect_component_titles` function means that the names of the components don't matter as long as they are unique per component throughout the environment.

##### Components

* `Owncloud_app::Database[.*]`
   - You must have only one of these
* `Owncloud_app::Web[.*]`
   - You can have one or more of these
   - consumes from `Database`

##### Parameters

* `database`: The database name (defalut `'owncloud'`).
* `db_user`: The database user for the application (default: `'owncloud'`).
* `db_pass`: The password for the database (default: `'owncloud'`).
* `web_int`: The interface the webserver listens on (default: `'enp0s8'`)..

### Component Types

#### `owncloud_app::database`

The application component to manage the Owncloud database.

##### Capabilities

- Produces a `Database` capabality resource for the MySQL database

##### Parameters

* `database`: The database name for this application (default: `'owncloud'`).
* `user`: The application user that will connect to the database (default: `'owncloud'`).
* `password`: The password the application uses to connect to the database (default: `'owncloud'`).


#### `owncloud_app::web`

The application component to manage Owncloud and Apache.

##### Capabilities

- Consumes the `Database` capability resource for the MySQL database
- Produces an `Http` capability resource for Owncloud

##### Parameters

* `db_host`: The database host.
* `db_port`: The database port.
* `db_name`: The database name.
* `db_user`: The database user.
* `db_password`: The database password.
* `apache_port`: The Apache port Owncloud listens on (default: `'8080'`).
* `interface`: The interface Apache listens on.
* `manage_db`: Should the component module manage the db deployment (default: `'false'`)

### Classes

#### `owncloud_app::database_profile`

The class that manages the MySQL server and firewall rules.

##### Parameters

none

#### `owncloud_app::web_profile`

The class that manages the MySQL client libraries.

##### Parameters

none
