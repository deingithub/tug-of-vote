require "http/client"
require "json"

def notify_list_addition(list_id, vote_cap)
  list = DATABASE.query_one("select * from lists where id = ?", list_id, as: List)
  unless list.webhook_url.empty?
    json = JSON.build do |builder|
      builder.object do
        builder.field "text", "**New Poll:** #{ENV["BASE_URL"]}/cap/#{vote_cap} @here"
      end
    end
    begin
      HTTP::Client.post(
        list.webhook_url,
        HTTP::Headers{"Content-Type" => "application/json"},
        json.to_s
      )
    rescue e
      LOG.error "Sending Webhook for list##{list_id} failed: #{e}"
    end
  end
end
