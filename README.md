# Ruby gem for multi-region database support on Fly.io

Running database replicas alongside your apps on Fly.io [is quick and easy](https://fly.io/docs/getting-started/multi-region-databases/). For read-heavy applications, this approach can increase an app's perceived speed.

The catch: in most primary/replica setups, you have only one writeable primary located in a specific region. Requests that write to the database should be sent directly to the web instance coloated with the primary database.

This gem integrates with Rails to automate write request routing for regionally distributed Postgresql clusters on Fly.

Currently, it does so by:

* modifying the `DATABASE_URL` to point apps to their regional replica
* catching Postgresql write exceptions to ask Fly to replay the request in the primary region

## Installation and requirements

Just add to your `Gemfile` and `bundle install`:

`gem "fly-multiregion"`

You should also have [setup a postgres cluster](https://fly.io/docs/getting-started/multi-region-databases/) on Fly. Then:

* ensure that your Postgresql and application regions match up
* ensure that no backup regions are assigned to your application
* attach the Postgres cluster to your application with `fly postgres attach`

Finally, set the `FLY_PRIMARY_REGION` environment variable in your app `fly.toml` to match the primary database region.

## Known issues

This gem will send all requests to the primary if you do something like update a user's database session on every GET request.

If your replica becomes writeable for some reason, this technique could backfire and leave your cluster out of sync.

## TODO

Here are some ideas for improving this gem.

* Add tests!
* Make environment variable names configurable
* Improve safety and performance option to send all POST/PATCH/DELETE requests to the primary region
* Use Rails read/write database split and ActiveJob to allow sending async writes to the primary database over the private network