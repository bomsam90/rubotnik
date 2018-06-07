require 'httparty'
require 'json'

module Rubotnik
  module Helpers
    # Mixed-in methods become private
    module_function

    GRAPH_URL = 'https://graph.facebook.com/v2.8/'.freeze

    # abstraction over Bot.deliver to send messages declaratively and directly
    def say(text, quick_replies: [], user: @user)
      message_options = {
        recipient: { id: user.id },
        message: { text: text }
      }
      if quick_replies && !quick_replies.empty?
        message_options[:message][:quick_replies] = UI::QuickReplies
                                                      .build(*quick_replies)
      end

      send_message(message_options)
    end

    def show(ui_element, user: @user)
      payload = ui_element.build(user)

      send_message(payload)
    end

    def next_command(command)
      @user.assign_command(command)
    end

    def stop_thread
      @user.reset_command
    end

    def text_message?
      @message.respond_to?(:text) && !@message.text.nil?
    end

    def message_contains_location?
      !@message.attachments.nil? && @message.attachments.first['type'] == 'location'
    end

    # Get user info from Graph API. Takes names of required fields as symbols
    # https://developers.facebook.com/docs/graph-api/reference/v2.2/user
    def get_user_info(*fields)
      str_fields = fields.map(&:to_s).join(',')
      url = GRAPH_URL + @user.id + '?fields=' + str_fields + '&access_token=' +
            ENV['ACCESS_TOKEN']
      begin
        return call_graph_api(url)
      rescue => e
        return false
      end
    end

    def call_graph_api(url)
      @message.typing_on
      response = HTTParty.get(url)
      @message.typing_off
      case response.code
      when 200
        Rubotnik.logger.info "Data received from Graph API: #{response.body}" # logging
        return JSON.parse(response.body, symbolize_names: true)
      else
        Rubotnik.logger.info "Request failed: #{response.body}"
        return false
      end
    end

    def send_message(payload)
      Bot.deliver(payload, access_token: ENV['ACCESS_TOKEN'])
    end
  end
end
