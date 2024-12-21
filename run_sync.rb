#!/usr/bin/env ruby

require 'bundler/setup'
require_relative 'lib/sync'

sync = Sync.new

# close the connection cleanly on Ctrl+C
trap("SIGINT") { sync.log "Stopping..."; sync.stop }
trap("SIGTERM") { sync.log "Stopping..."; sync.stop }

sync.start
