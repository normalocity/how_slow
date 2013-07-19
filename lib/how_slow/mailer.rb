require 'action_mailer'

class HowSlow::Mailer < ActionMailer::Base
  # This method expects an `options` hash in the following format (the default
  # values are shown as examples):
  #
  # {
  #   :subject => "metrics report",
  #   :actions => {
  #     :sort_by => :total_runtime,
  #     :show_measurements => [:total_runtime, :db_runtime, :view_runtime]
  #     :number_of_actions => 50,
  #     :retention => 7.days.ago
  #   },
  #   :counters => {
  #     :event_names => nil,                      # the names of counter metrics to include, or `nil` to
  #                                               # include all of them
  #     :retention => 7.days.ago
  #     :sort => :alpha_asc                       # one of (:alpha_asc, :alpha_desc, :numeric_asc, :numeric_desc)
  #   }
  # }
  #
  # See lib/how_slow/setup.rb for default values
  def metrics_email(options={})
    options = HowSlow::config.merge(options)

    sender = options[:email_sender_address]
    recipients = options[:email_recipients]
    subject = options[:email_subject]
    HashWithIndifferentAccess.new(options) unless options.class == HashWithIndifferentAccess

    reporter = HowSlow::Reporter.new

    @action_metrics = []
    @action_sort_by = options[:email_actions_sort]
    number_of_actions = options[:email_actions_max]
    @action_keep_since = options[:email_actions_retention].ago
    
    @action_metrics = reporter.slowest_actions_by(@action_sort_by, number_of_actions, @action_keep_since)
  
    @counter_metrics = []

    event_names = options[:email_counters_events] || reporter.all_counter_event_names
    @counter_retention = options[:email_counters_retention].ago

    @counter_sort_by = options[:email_counters_sort]
    event_names.each{|e| @counter_metrics << reporter.sum_counters_by(e, @counter_retention) }

    case @counter_sort_by
      when :alpha_asc     then @counter_metrics.sort!{|a, b| a.event_name <=> b.event_name }
      when :alpha_desc    then @counter_metrics.sort!{|a, b| b.event_name <=> a.event_name }
      when :numeric_asc   then @counter_metrics.sort!{|a, b| a.count <=> b.count }
      when :numeric_desc  then @counter_metrics.sort!{|a, b| b.count <=> a.count }
    end

    mail(:from => sender, :to => recipients, :subject => subject)
  end
end
