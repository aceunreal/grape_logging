require 'grape/middleware/base'

module GrapeLogging
  module Middleware
    class RequestLoggerLimited < Grape::Middleware::Base
      def before
        start_time

        @db_duration = 0
        @subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          @db_duration += event.duration
        end if defined?(ActiveRecord)
      end

      def after
        stop_time
        logger.info parameters
        nil
      end

      def call!(env)
        super
      ensure
        ActiveSupport::Notifications.unsubscribe(@subscription) if @subscription
      end

      protected
      def parameters
        {
          path: request.path,
          headers: headers,
          method: request.request_method,
          total: total_runtime,
          db: @db_duration.round(2),
          status: @app_response.try(:status) || 200
        }
      end

      private
      def logger
        @logger ||= @options[:logger] || Logger.new(STDOUT)
      end

      def request
        @request ||= ::Rack::Request.new(env)
      end

      def headers
        @header ||= Hash[*env.select { |k, v| k.start_with? 'HTTP_USER_AGENT' }
                            .collect { |k, v| [k.sub(/^HTTP_/, ''), v] }
                            .collect { |k, v| [k.split('_').collect(&:capitalize).join('-'), v] }
                            .sort
                            .flatten]
      end

      def total_runtime
        ((stop_time - start_time) * 1000).round(2)
      end

      def start_time
        @start_time ||= Time.now
      end

      def stop_time
        @stop_time ||= Time.now
      end
    end
  end
end
