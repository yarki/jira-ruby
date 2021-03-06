require 'cgi'

module JIRA
  module Resource

    class IssueFactory < JIRA::BaseFactory # :nodoc:
    end

    class Issue < JIRA::Base

      has_one :reporter,  :class => JIRA::Resource::User,
                          :nested_under => 'fields'
      has_one :assignee,  :class => JIRA::Resource::User,
                          :nested_under => 'fields'
      has_one :project,   :nested_under => 'fields'

      has_one :issuetype, :nested_under => 'fields'

      has_one :priority,  :nested_under => 'fields'

      has_one :status,    :nested_under => 'fields'

      has_many :transitions

      has_many :components, :nested_under => 'fields'

      has_many :comments, :nested_under => ['fields','comment']

      has_many :attachments, :nested_under => 'fields',
                          :attribute_key => 'attachment'

      has_many :versions, :nested_under => 'fields'

      has_many :worklogs, :nested_under => ['fields','worklog']

      def self.all(client)
        response = client.get(
          client.options[:rest_base_path] + "/search",
          :expand => 'transitions.fields'
        )
        json = parse_json(response.body)
        json['issues'].map do |issue|
          client.Issue.build(issue)
        end
      end

      def self.jql(client, jql, fields = nil, startAt = 0, maxResults = 50)
        url = client.options[:rest_base_path] + "/search?jql=" + CGI.escape(jql)
        url += "&fields=#{CGI.escape(fields.join(","))}" if fields
        url += "&startAt=#{startAt}&maxResults=#{maxResults}"
        response = client.get(url)
        json = parse_json(response.body)
        json['issues'].map do |issue|
          client.Issue.build(issue)
        end
      end

      def all_worklogs
        search_url = "#{client.options[:rest_base_path]}/issue/#{id}/worklog"
        response = client.get(search_url)
        json = self.class.parse_json(response.body)
        json['worklogs'].map do |worklog|
          JIRA::Resource::Worklog.new(client, attrs: worklog, issue: self)
        end
      end

      def has_parent?
        fields.include?('parent')
      end

      def parent
        client.Issue.find(fields['parent']['id'])
      end

      def has_linked_epic?
        !linked_epic_key.nil?
      end

      def linked_epic_key
        fields['customfield_14500']
      end

      def linked_epic
        client.Issue.find(fields['customfield_14500'])
      end

      def respond_to?(method_name)
        if attrs.keys.include?('fields') && attrs['fields'].keys.include?(method_name.to_s)
          true
        else
          super(method_name)
        end
      end

      def method_missing(method_name, *args, &block)
        if attrs.keys.include?('fields') && attrs['fields'].keys.include?(method_name.to_s)
          attrs['fields'][method_name.to_s]
        else
          super(method_name)
        end
      end

    end

  end
end
