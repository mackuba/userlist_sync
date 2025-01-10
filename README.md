# Userlist Sync

A small tool written in Ruby for adding all users with handles matching some kind of pattern (e.g. all [*.gov](https://bsky.app/profile/did:plc:oio4hkxaop4ao4wz2pp3f4cr/lists/3lcq5ovmsjn2s)) to a user list on Bluesky.


## How to use

1) Deploy this repo to some kind of server using a method of your choice (manual `git clone`, Capistrano, etc.).

2) Make sure you have a reasonably new version of Ruby installed there. Any recent Linux distribution should have Ruby 3.0 or newer available as a package (as of January 2025, the latest version is 3.4.1, 3.1.x is in security maintenance mode, and 3.0.x is EOL); however, this code should work with 2.6 or 2.7 too, though that's not recommended. You can also install Ruby using tools such as [RVM](https://rvm.io), [asdf](https://asdf-vm.com), [ruby-install](https://github.com/postmodern/ruby-install) or [ruby-build](https://github.com/rbenv/ruby-build).

3) `cd` into the project directory and install gem dependencies using `bundle`. You might want to configure it to install the gems into the local directory instead of system-wide, e.g.:

```
bundle config --local bundle_path ./vendor
bundle
```

4) Create a `config/auth.yml` file with authentication info for the account that manages the lists. It should look like this (sorry, no OAuth yet):

```
id: your.handle
pass: app-pass-word
```

This file will also be used to keep access tokens (try to delete the tokens from there if something goes wrong and the app can't authenticate).

5) Create a second config file `config/config.yml` with options for the list and handles:

```
jetstream_host: jetstream2.us-east.bsky.network
handle_patterns:
  - "*.uk"
list_key: 3lqwertyuiop
```

Fields in the config:

- `jetstream_host` - Jetstream server hostname, see [here](https://github.com/bluesky-social/jetstream?tab=readme-ov-file#public-instances)
- `handle_patterns` - list of one or more handle patterns to look for; the entries are currently not regexps, but just simple patterns with `*` matching one or more characters
- `list_key` - the *rkey* of the list to which accounts should be added (the last part of the list URL)

6) Test if the app works by running:

```
./run_sync.rb
```

The app will save some data like current cursor and list of known accounts to `data/data.json` (on first run, it will fetch the initial state of the list first).

7) Use something like `systemd` to launch the service automatically and keep it running (you can find a sample systemd service file in the [dist folder](https://github.com/mackuba/userlist_sync/blob/master/dist/userlist_sync.service)).


## Credits

Copyright © 2024-25 Kuba Suder ([@mackuba.eu](https://bsky.app/profile/mackuba.eu)).

The code is available under the terms of the [zlib license](https://choosealicense.com/licenses/zlib/) (permissive, similar to MIT).

Bug reports and pull requests are welcome 😎
