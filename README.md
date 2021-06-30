# Enhance Rails apps on Fly.io

Fly offers a number of native features that can improve the perceived speed and observability of Rails apps with minimal configuration. This gem automates some of the work required to take advantage of these features.

## Regional replicas 

Running database replicas alongside your apps in multiple regions [is quick and easy with built-in Postgresql support](https://fly.io/docs/getting-started/multi-region-databases/). This can increase the perceived speed of read-heavy applications.

The catch: in most primary/replica setups, you have only one writeable primary located in a specific region. Requests that write to the database should be sent directly to the web instance coloated with the primary database.

This gem will automatcally route requests that write to the database to the primary region.

Currently, it does so by:

* modifying the `DATABASE_URL` to point apps to their local regional replica
* catching Postgresql exceptions caused by writes to a read-only replica, and redirecting these requests to the primary region

## Installation and requirements

Just add to your `Gemfile` and `bundle install`:

`gem "fly-rails"`

You should also have [setup a postgres cluster](https://fly.io/docs/getting-started/multi-region-databases/) on Fly. Then:

* ensure that your Postgresql and application regions match up
* ensure that no backup regions are assigned to your application
* attach the Postgres cluster to your application with `fly postgres attach`

Finally, set the `FLY_PRIMARY_REGION` environment variable in your app `fly.toml` to match the primary database region.

## Known issues

This gem will send all requests to the primary if you do something like update a user's database session on every GET request.

If your replica becomes writeable due to an outage on the primary, your custer may get out of sync.

## TODO

Here are some ideas for improving this gem.

* Add tests!
* Make environment variable names configurable
* Improve safety and performance option to send all POST/PATCH/DELETE requests to the primary region
* Use Rails read/write database split and ActiveJob to allow sending async writes to the primary database over the private network
