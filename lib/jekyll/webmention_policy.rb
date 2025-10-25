# frozen_string_literal: true

module Jekyll
  module WebmentionIO
    # The WebmentionPolicy class encapsulates all the configuration and
    # state management logic for dealing with request failures.
    class WebmentionPolicy
      module State
        UNSUPPORTED = 'unsupported'
        ERROR = 'error'
        FAILURE = 'failure'
        SUCCESS = 'success'
      end

      def initialize(config, caches)
        @config = config
        @caches = caches
      end

      # Check if we should attempt to send a webmention to the given URI based
      # on the error handling policy and the last attempt.
      def uri_ok?(uri)
        uri = URI::Parser.new.parse(uri.to_s)
        uri_str = uri.to_s

        # If the URI is whitelisted, it's always ok!
        return true if @config.bad_uri_policy.whitelist.any? { |expr| expr.match uri_str }

        # If the URI is blacklisted, it's never ok!
        return false if @config.bad_uri_policy.blacklist.any? { |expr| expr.match uri_str }

        entry = get_bad_uri_cache_entry(uri)

        # If the entry isn't in our cache yet, then it's ok.
        return true if entry.nil?

        # Okay, the last time we tried to send a webmention to this URI it
        # failed, so depending on what happened and the policy, we need to
        # decide what to do.
        #
        # First pull the retry policy given the type of the last error for the URI
        policy_entry = @config.bad_uri_policy.for_state(entry['state'])

        return false if policy_entry.policy == Config::UriPolicy::BAN

        return true if policy_entry.policy == Config::UriPolicy::IGNORE

        if policy_entry.policy == Config::UriPolicy::RETRY
          now = Time.now

          attempts = entry['attempts']
          max_attempts = policy_entry.max_attempts

          if !max_attempts.nil? && (attempts >= max_attempts)
            # If there's a retry limit and we've hit it, URI is not ok.
            Jekyll::WebmentionIO.log 'msg', "Skipping #{uri}, attempted #{attempts} times and max is #{max_attempts}"

            return false
          end

          retry_delay = policy_entry.retry_delay

          # Sneaky trick.  By clamping to the array length, the last entry in
          # the retry_delay list is used for all remaining retries.
          delay = retry_delay[(attempts - 1).clamp(0, retry_delay.length - 1)]

          recheck_at = (entry['last_checked'] + delay * 3600)

          if recheck_at.to_r > now.to_r
            Jekyll::WebmentionIO.log 'msg', "Skipping #{uri}, next attempt will happen after #{recheck_at}"

            return false
          end
        else
          Jekyll::WebmentionIO.log 'error', "Invalid bad URI policy type: #{policy}"
        end

        true
      end

      # Update our URI cache to indicate that the last request for the given
      # URI was a success.
      def success(uri)
        update_uri_cache(uri, State::SUCCESS)
      end

      # Update our URI cache to indicate that the last request for the given
      # URI resulted in an error being returned from the target.
      def error(uri)
        update_uri_cache(uri, State::ERROR)
      end

      # Update our URI cache to indicate that the last request for the given
      # URI resulted in an failure in accessing the given resource.
      def failure(uri)
        update_uri_cache(uri, State::FAILURE)
      end

      # Update our URI cache to indicate that endpoint indicated by the given
      # URI is not available/supported (for example, if an attempt was made to
      # send a webmention to a site that doesn't support them).
      def unsupported(uri)
        update_uri_cache(uri, State::UNSUPPORTED)
      end

      # Determines webmention gathering for the given post should or should not
      # be delayed/throttled in order to minimize load on webmention.io based
      # on the configured throttling policy.
      #
      # allowed throttles: last_week, last_month, last_year, older
      # allowed values:  daily, weekly, monthly, yearly, every X days|weeks|months|years
      def post_should_be_throttled?(post, item_date, last_lookup)
        return unless item_date && last_lookup

        lookup_threshold = @config.last_lookup_threshold(item_date)

        return if lookup_threshold.nil? || (last_lookup <= lookup_threshold)

        Jekyll::WebmentionIO.log 'info', "Throttling #{post.data['title']} due to policy (last was #{last_lookup}, threshold is #{lookup_threshold})"

        true
      end

      private

      # Retrieve the bad_uris cache entry for the given URI.  This method
      # takes the cache and a URI instance (i.e. parsing must already be done).
      #
      # If the URI has no entry in the cache, returns nil and *not* a default
      # entry.
      def get_bad_uri_cache_entry(uri)
        bad_uris = @caches.bad_uris

        return nil if !bad_uris.key? uri.host

        entry = bad_uris[uri.host].clone

        if entry.instance_of? String
          # Older version of the bad URL cache, convert to new format with some
          # "sensible" defaults.

          entry = {
            'state' => State::UNSUPPORTED,
            'last_checked' => DateTime.parse(entry).to_time,
            'attempts' => 1
          }
        else
          # Otherwise, parse the check time into a real Time object before
          # returning the entry.
          #
          # We convert to a Time object so we can do arithmetic on it later.

          entry['last_checked'] = DateTime.parse(entry['last_checked']).to_time
        end

        entry
      end

      # Update the URI cache for this entry.
      #
      # If the state is State.SUCCESS or the URI is whitelisted or
      # blacklisted, we delete any existing entries since no policy will
      # apply.  This ensures we reset the policy state when a webmention
      # succeeds.
      #
      # Otherwise, we either create or update an entry for the URI, recording
      # the state and the current attempt counter.
      def update_uri_cache(uri, state)
        uri = URI::Parser.new.parse(uri.to_s)
        uri_str = uri.to_s

        bad_uris = @caches.bad_uris

        if (state == State::SUCCESS) ||
           @config.bad_uri_policy.whitelist.any? { |expr| expr.match uri_str } ||
           @config.bad_uri_policy.blacklist.any? { |expr| expr.match uri_str }

          return if bad_uris.delete(uri.host).nil?
        else
          old_entry = get_bad_uri_cache_entry(uri) || {}

          bad_uris[uri.host] = {
            'state' => state,
            'attempts' => old_entry.fetch('attempts', 0) + 1,
            'last_checked' => Time.now.to_s
          }
        end

        bad_uris.write
      end

      private_constant :State
    end
  end
end
