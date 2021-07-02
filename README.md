[![Test](https://github.com/soupedup/fly-rails/actions/workflows/test.yml/badge.svg)](https://github.com/soupedup/fly-rails/actions/workflows/test.yml)

# Augment Ruby web apps on Fly.io

[Fly.io](https://fly.io) offers a number of native features that can improve the perceived speed and observability of Rails apps with minimal configuration. This gem automates some of the work required to take advantage of these features.

## Regional replicas 

Running database replicas alongside your apps in multiple regions [is quick and easy with Fly's Postgresql cluster](https://fly.io/docs/getting-started/multi-region-databases/). This can increase the perceived speed of read-heavy applications.

The catch: in most primary/replica setups, you have one writeable primary located in a specific region. Fly solves this by allowing requests to be *replyed*, at the routing layer, in another region.

This repository includes the `fly-ruby` gem which will utomatcally route requests that write to the database to the primary region. It should work
with any Rack-compatible Ruby framework.

Currently, it does this by:

* modifying the `DATABASE_URL` to point apps to their local regional replica
* replaying non-idempotent (post/put/patch/delete) requests in the primary region
* catching Postgresql exceptions caused by writes to a read-only replica, and replaying these requests in the primary region

## Requirements

You should have [setup a postgres cluster](https://fly.io/docs/getting-started/multi-region-databases/) on Fly. Then:

* ensure that your Postgresql and application regions match up
* ensure that no backup regions are assigned to your application
* attach the Postgres cluster to your application with `fly postgres attach`

Finally, set the `PRIMARY_REGION` environment variable in your app `fly.toml` to match the primary database region.

## Installation

If you're on Rails, add to your Gemfile and `bundle install`:

`gem "fly-rails`

The middleware will insert itself automatically at the top of the Rack middleware stack.

For other frameworks, use:

`gem "fly-ruby"`

## Configuration

Most values used by this middleware are configurable. On Rails, this might go in an initializer like `config/initializers/fly.rb`

```
Fly.configure do |c|
  c.replay_threshold_in_seconds = 10
end
```

See [the source code](https://github.com/soupedup/fly-rails/blob/main/lib/fly-rails/configuration.rb) for defaults and available configuration options.
## Known issues

This middleware send all requests to the primary if you do something like update a user's database session on every GET request.

If your replica becomes writeable for some reason, your custer may get out of sync.

## TODO

Here are some ideas for improving this gem.

* Add a helper to invoke ActiveJob, and possibly AR read/write split support, to send GET-originated writes to the primary database in the background

