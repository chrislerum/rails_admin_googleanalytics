require 'rails_admin/config/proxyable'
require 'rails_admin/config/configurable'
require 'rails_admin/config/hideable'
require 'google/api_client'

module RailsAdmin
  module Config
    module Actions
      class AnalyticsIndex < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
        include RailsAdmin::Config::Proxyable
        include RailsAdmin::Config::Configurable
        include RailsAdmin::Config::Hideable

        register_instance_option :only do
          nil
        end

        register_instance_option :except do
          []
        end

        # http://twitter.github.com/bootstrap/base-css.html#icons
        register_instance_option :link_icon do
          'icon-th'
        end

        # Should the action be visible
        register_instance_option :visible? do
          authorized?
        end

        register_instance_option :authorized? do
          (
          bindings[:controller].nil? or bindings[:controller].authorized?(self.authorization_key, bindings[:abstract_model], bindings[:object])
          ) and (
          bindings[:abstract_model].nil? or (
          (only.nil? or [only].flatten.map(&:to_s).include?(bindings[:abstract_model].to_s)) and
              ![except].flatten.map(&:to_s).include?(bindings[:abstract_model].to_s) and
              bindings[:abstract_model].config.with(bindings).visible?
          ))
        end

        # Is the action acting on the root level (Example: /admin/contact)
        register_instance_option :root? do
          true
        end

        # Is the action on a model scope (Example: /admin/team/export)
        register_instance_option :collection? do
          false
        end

        # Is the action on an object scope (Example: /admin/team/1/edit)
        register_instance_option :member? do
          false
        end

        # Render via pjax?
        register_instance_option :pjax? do
          false
        end

        # This block is evaluated in the context of the controller when action is called
        # You can access:
        # - @objects if you're on a model scope
        # - @abstract_model & @model_config if you're on a model or object scope
        # - @object if you're on an object scope
        register_instance_option :controller do
          Proc.new do
            # Update these to match your own apps credentials
            service_account_email = Settings.google_analytics.service_account_email # Email of service account
            key_file = Settings.google_analytics.key_file # File containing your private key
            key_secret = Settings.google_analytics.key_secret # Password to unlock private key
            profileID = Settings.google_analytics.profile_id # Analytics profile ID.

            client = Google::APIClient.new({:application_name => 'rails_admin_googleanalytics', :application_version => '0.0.1'})

# Load our credentials for the service account
            key = Google::APIClient::KeyUtils.load_from_pkcs12(key_file, key_secret)
            client.authorization = Signet::OAuth2::Client.new(
                :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
                :audience => 'https://accounts.google.com/o/oauth2/token',
                :scope => 'https://www.googleapis.com/auth/analytics.readonly',
                :issuer => service_account_email,
                :signing_key => key)

# Request a token for our service account
            client.authorization.fetch_access_token!

            analytics = client.discovered_api('analytics','v3')

            startDate = (Date.today - 30).strftime("%Y-%m-%d")
            endDate = Date.today.strftime("%Y-%m-%d")

            visitCount = client.execute(:api_method => analytics.data.ga.get, :parameters => {
                'ids' => "ga:" + profileID,
                'start-date' => startDate,
                'end-date' => endDate,
                'dimensions' => "ga:month,ga:day",
                'metrics' => "ga:pageviews,ga:uniquePageviews",
                'sort' => "ga:month,ga:day"
            })

            data = visitCount.data.rows.transpose
            @pageviews_data = data[2].collect(&p(:to_i))
            @unique_pageviews_data = data[3].collect(&p(:to_i))

            totalData = visitCount.data.totalsForAllResults
            @pageviews = totalData['ga:pageviews']
            @unique_pageviews = totalData['ga:uniquePageviews']

            startDate = "2013-08-12"

            totalVisitCount = client.execute(:api_method => analytics.data.ga.get, :parameters => {
                'ids' => "ga:" + profileID,
                'start-date' => startDate,
                'end-date' => endDate,
                'metrics' => "ga:pageviews,ga:uniquePageviews",
                'dimensions' => 'ga:fullReferrer',
                'sort' => '-ga:pageviews',
                'max-results' => 15
            })

            totalData = totalVisitCount.data.totalsForAllResults
            @total_pageviews = totalData['ga:pageviews']
            @total_unique_pageviews = totalData['ga:uniquePageviews']
            @total_referrers = totalVisitCount.data.rows

            topPagesCount = client.execute(:api_method => analytics.data.ga.get, :parameters => {
                'ids' => "ga:" + profileID,
                'start-date' => startDate,
                'end-date' => endDate,
                'metrics' => "ga:pageviews,ga:uniquePageviews",
                'dimensions' => 'ga:pageTitle,ga:pagePath',
                'sort' => '-ga:pageviews',
                'max-results' => 15
            })

            @top_pages = topPagesCount.data.rows

            render :action => :analytics
          end
        end

        # Model scoped actions only. You will need to handle params[:bulk_ids] in controller
        register_instance_option :bulkable? do
          false
        end

        # View partial name (called in default :controller block)
        register_instance_option :template_name do
          key.to_sym
        end

        # For Cancan and the like
        register_instance_option :authorization_key do
          :analytics_index
        end

        # List of methods allowed. Note that you are responsible for correctly handling them in :controller block
        register_instance_option :http_methods do
          [:get]
        end

        # Url fragment
        register_instance_option :route_fragment do
          'analytics'
        end

        # Controller action name
        register_instance_option :action_name do
          custom_key.to_sym
        end

        # I18n key
        register_instance_option :i18n_key do
          key
        end

        # User should override only custom_key (action name and route fragment change, allows for duplicate actions)
        register_instance_option :custom_key do
          key
        end

        # Breadcrumb parent
        register_instance_option :breadcrumb_parent do
          case
            when root?
              [:dashboard]
            when collection?
              [:index, bindings[:abstract_model]]
            when member?
              [:show, bindings[:abstract_model], bindings[:object]]
          end
        end

        # Off API.

        def key
          self.class.key
        end

        def self.key
          self.name.to_s.demodulize.underscore.to_sym
        end
      end
    end
  end
end
