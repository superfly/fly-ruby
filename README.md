[![Test](https://github.com/superfly/fly-ruby/actions/workflows/test.yml/badge.svg)](https://github.com/superfly/fly-ruby/actions/workflows/test.yml)

This gem contains helper code and Rack middleware for deploying Ruby web apps on [Fly.io](https://fly.io). It's designed to speed up apps by using region-local Postgresql replicas for database reads. See the blog post for more details:

https://fly.io/blog/run-ordinary-rails-apps-globally

## Speed up apps using region-local database replicas

Fly's [cross-region private networking](https://fly.io/docs/reference/privatenetwork/) makes it easy to run database replicas [alongside your app instances in multiple regions](https://fly.io/docs/getting-started/multi-region-databases/). These replicas can be used for faster reads and application performance.

Writes, however, will be slow if performed across regions. Fly allows web apps to specify that a request be *replayed*, at the routing layer, in another region.

This gem includes Rack middleware to automatically route such requests to the primary region. It's designed should work with any Rack-compatible Ruby framework.

Currently, it does this by:

* modifying the `DATABASE_URL` to point apps to their local regional replica
* replaying non-idempotent (post/put/patch/delete) requests in the primary region
* catching Postgresql exceptions caused by writes to a read-only replica, and asking for
  these requests to be replayed in the primary region
* replaying all requests within a time threshold after a write, to avoid users seeing
  their own stale data due to replication lag

## Requirements

You should have [setup a postgres cluster](https://fly.io/docs/getting-started/multi-region-databases/) on Fly. Then:

* ensure that your Postgresql and application regions match up
* ensure that no backup regions are assigned to your application
* attach the Postgres cluster to your application with `fly postgres attach`

Finally, set the `PRIMARY_REGION` environment variable in your app `fly.toml` to match the primary database region.

## Installation

Add to your Gemfile and `bundle install`:

`gem "fly-ruby"`

If you're on Rails, the middleware will insert itself automatically, and attempt to reconnect the database.

## Configuration

Most values used by this middleware are configurable. On Rails, this might go in an initializer like `config/initializers/fly.rb`

```
Fly.configure do |c|
  c.replay_threshold_in_seconds = 10
end
```

See [the source code](https://github.com/superfly/fly-ruby/blob/main/lib/fly-ruby/configuration.rb) for defaults and available configuration options.
## Known issues

This middleware send all requests to the primary if you do something like update a user's database session on every GET request.

If your replica becomes writeable for some reason, your cluster may get out of sync.

## TODO

Here are some ideas for improving this gem.

* Add a helper to invoke ActiveJob, and possibly AR read/write split support, to send GET-originated writes to the primary database in the background

