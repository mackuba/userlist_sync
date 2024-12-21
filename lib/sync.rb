require 'didkit'
require 'fileutils'
require 'json'
require 'minisky'
require 'set'
require 'skyfall'
require 'yaml'

class Sync
  class ConfigError < StandardError
  end

  def initialize(config_file: 'config/config.yml', data_file: 'data/data.json', auth_file: 'config/auth.yml')
    log "Initializing..."

    @config = load_config(config_file)
    @data = load_data(data_file)
    @data_file = data_file
    @sky = init_minisky(auth_file)

    @handle_regexps = @config['handle_patterns'].map { |x| regexp_from_pattern(x) }
    @list_uri = "at://#{@sky.user.did}/app.bsky.graph.list/#{@config['list_key']}"

    @members = @data['list_members'] ? Set.new(@data['list_members']) : fetch_list_members
  end

  def start
    @jetstream = Skyfall::Jetstream.new(@config['jetstream_host'], {
      wanted_collections: 'app.bsky.none',
      cursor: @data['cursor']
    })

    @jetstream.on_connecting { |u| log "Connecting to #{u}..." }
    @jetstream.on_connect { log "Connected ✓" }
    @jetstream.on_disconnect { log "Disconnected." }
    @jetstream.on_reconnect { log "Reconnecting..." }
    @jetstream.on_error { |e| log "ERROR: #{e} #{e.message}" }

    @jetstream.on_message do |msg|
      if msg.type == :identity && msg.handle
        process_identity(msg)
      end
    end

    @jetstream.connect
  end

  def stop
    save_data
    @jetstream.disconnect
  end

  def log(s)
    puts "#{Time.now}: #{s}"
    $stdout.flush
  end


  private

  def process_identity(msg)
    return unless @handle_regexps.any? { |r| msg.handle =~ r }
    return if @members.include?(msg.did)

    did = DID.resolve_handle(msg.handle)

    if did.nil? || did.to_s != msg.did
      log "Error: @#{msg.handle} does not resolve to #{msg.did}"
      return
    end

    add_did_to_list(msg.did)
    log "Added account to list: @#{msg.handle} (#{msg.did})"
  end

  def add_did_to_list(did)
    @sky.post_request('com.atproto.repo.createRecord', {
      repo: @sky.user.did,
      collection: 'app.bsky.graph.listitem',
      record: {
        subject: did,
        list: @list_uri,
        createdAt: Time.now.iso8601
      }
    })

    @members << did
    save_data
  end

  def fetch_list_members
    @sky.check_access

    print "#{Time.now}: Syncing current list items: "
    records = @sky.fetch_all('com.atproto.repo.listRecords',
      { repo: @sky.user.did, collection: 'app.bsky.graph.listitem' },
      field: 'records', progress: '.')

    members = records.map { |x| x['value'] }.select { |x| x['list'] == @list_uri }.map { |x| x['subject'] }.uniq
    puts " #{members.length} ✓"

    Set.new(members)
  end

  def load_config(config_file)
    config_path = File.join(__dir__, '..', config_file)

    if !File.exist?(config_path)
      raise ConfigError, "Missing config file at #{config_file}"
    end

    config = YAML.load(File.read(config_path))

    jetstream = config['jetstream_host']

    if jetstream.nil?
      raise ConfigError, "Missing 'jetstream_host' field in the config file"
    end

    if !jetstream.is_a?(String) || jetstream.strip.empty?
      raise ConfigError, "Invalid 'jetstream_host' field in the config file (should be a string): #{jetstream.inspect}"
    end

    patterns = config['handle_patterns']

    if patterns.nil?
      raise ConfigError, "Missing 'handle_patterns' field in the config file"
    end

    if !patterns.is_a?(Array) || patterns.empty? || !patterns.all? { |p| p.is_a?(String) }
      raise ConfigError, "Invalid 'handle_patterns' field in the config file (should be an array of strings)"
    end

    rkey = config['list_key']

    if rkey.nil?
      raise ConfigError, "Missing 'list_key' field in the config file"
    end

    if !rkey.is_a?(String) || rkey.length != 13
      raise ConfigError, "Invalid 'list_key' field in the config file (should be a 13-character string)"
    end

    config
  end

  def load_data(data_file)
    data_path = File.join(__dir__, '..', data_file)

    File.exist?(data_path) ? JSON.parse(File.read(data_path)) : {}
  end

  def save_data
    @data['cursor'] = @jetstream.cursor
    @data['list_members'] = @members.to_a

    data_path = File.join(__dir__, '..', @data_file)
    FileUtils.mkdir_p(File.dirname(data_path))
    File.write(data_path, JSON.pretty_generate(@data))
  end

  def init_minisky(auth_file)
    auth_path = File.join(__dir__, '..', auth_file)

    if !File.exist?(auth_path)
      raise ConfigError, "Missing auth file at #{auth_file}"
    end

    data = YAML.load(File.read(auth_path))

    if data['id'].nil?
      raise ConfigError, "Missing 'id' field in the auth file"
    end

    did = if data['did']
      DID.new(data['did'])
    elsif data['id'] =~ /^did:/
      DID.new(data['id'])
    else
      DID.resolve_handle(data['id'])
    end

    if did.nil?
      raise ConfigError, "Couldn't resolve handle: @#{data['id']}"
    end

    pds = did.get_document.pds_endpoint.gsub('https://', '')

    sky = Minisky.new(pds, auth_path)
    sky.check_access
    sky
  end

  def regexp_from_pattern(s)
    Regexp.new("\\A" + s.gsub('.', "\\.").gsub('*', ".+") + "\\z")
  end
end
