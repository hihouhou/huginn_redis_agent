module Agents
  class RedisAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description do
      <<-MD
      The Redis Agent interacts with Redis server.

      `debug` is used for verbose mode.

      `redis_server` is mandatory to make requests to the server.

      `redis_port` is mandatory to make requests to the server.

      `redis_key` is mandatory to make requests to the server.

      `data` is needed when you want to use write_redis.

      `type` is for the wanted action like read_redis, write_redis.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "key": "mykey:bis",
            "data": "test1"
          }
    MD

    def default_options
      {
        'redis_server' => '',
        'redis_port' => '',
        'data' => '',
        'redis_key' => '',
        'type' => 'read_redis',
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
      }
    end

    form_configurable :redis_server, type: :string
    form_configurable :redis_port, type: :string
    form_configurable :data, type: :string
    form_configurable :redis_key, type: :string
    form_configurable :debug, type: :boolean
    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :type, type: :array, values: ['write_redis', 'read_redis']
    def validate_options
      errors.add(:base, "type has invalid value: should be 'write_redis', 'read_redis'") if interpolated['type'].present? && !%w(read_redis write_redis).include?(interpolated['type'])

      unless options['redis_server'].present? || !['write_redis' 'read_redis'].include?(options['type'])
        errors.add(:base, "redis_server is a required field")
      end

      unless options['redis_port'].present? || !['write_redis' 'read_redis'].include?(options['type'])
        errors.add(:base, "redis_port is a required field")
      end

      unless options['data'].present? || !['write_redis'].include?(options['type'])
        errors.add(:base, "data is a required field")
      end

      unless options['redis_key'].present? || !['write_redis' 'read_redis'].include?(options['type'])
        errors.add(:base, "redis_key is a required field")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          log event
          trigger_action
        end
      end
    end

    def check
      trigger_action
    end

    private

    def write_redis()

      redis = Redis.new(host: interpolated['redis_server'], port: interpolated['redis_port'])
      redis.set(interpolated['redis_key'], interpolated['data']);
      if interpolated['debug'] == 'true'
        log "data"
        log interpolated['data']
      end
      redis.quit

    end

    def read_redis()
      redis = Redis.new(host: interpolated['redis_server'], port: interpolated['redis_port'])
      redis_data = redis.get(interpolated['redis_key']);
      if redis_data.empty?
        if interpolated['debug'] == 'true'
          log "no data"
        end
      else
        if interpolated['debug'] == 'true'
          log "redis_data is #{redis_data}"
        end
        create_event payload: { 'key' => interpolated['redis_key'], 'data' => redis_data }
      end
      redis.quit

    end

    def trigger_action

      case interpolated['type']
      when "write_redis"
        write_redis()
      when "read_redis"
        read_redis()
      else
        log "Error: type has an invalid value (#{interpolated['type']})"
      end

    end
  end
end
