class HealthController < ActionController::Base
  skip_before_action :check_for_lockup, raise: false

  def show
    render json:, status:
  end

  private

  def json
    {
      **checks.transform_values { to_sym(it) },
      version: Rails.configuration.x.git.commit_version,
    }
  end

  def checks
    @checks ||= {
      postgresql: check_postgresql,
      redis: check_redis,
      influxdb: check_influxdb,
    }.compact
  end

  def status
    checks.values.all? ? :ok : :service_unavailable
  end

  def check_postgresql
    ActiveRecord::Base.logger.silence do
      ApplicationRecord.connection.select_value('SELECT 1') == 1
    end
  rescue StandardError
    false
  end

  def check_redis
    if Rails.cache.respond_to?(:redis)
      Rails.cache.redis.with { |r| r.ping == 'PONG' }
    end
  rescue StandardError
    false
  end

  def check_influxdb
    Flux::Base.new.client.ping.status == 'ok'
  rescue StandardError
    false
  end

  def to_sym(result)
    case result
    when true
      :ok
    when false
      :error
    end
  end
end
