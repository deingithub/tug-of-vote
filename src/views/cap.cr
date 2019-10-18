require "./cap_poll/main"
require "./cap_poll/actions"
require "./cap_list/main"
require "./cap_list/actions"

get "/cap/:cap_slug" do |env|
  rs = DATABASE.query "select poll_id, list_id, kind, cap_slug from caps where cap_slug = ?", env.params.url["cap_slug"]
  begin
    if rs.move_next
      result = rs.read(poll_id: Int64?, list_id: Int64?, kind: Int64, cap_slug: String)
      rs.close
      case CapKind.from_value(result[:kind])
      when CapKind::Revoked
        next gen_404(env)
      when CapKind::ListView, CapKind::ListAdmin
        next gen_list(result)
      when CapKind::PollAdmin, CapKind::PollVote, CapKind::PollView, CapKind::PollViewAnon
        next gen_poll(result)
      else
        next gen_500(env)
      end
    else
      next gen_404(env)
    end
  ensure
    rs.close
  end
end

def gen_404(env)
  env.response.status_code = 404
  error_text = "This URL is unknown, invalid or has been revoked. Sorry."
  render "src/ecr/cap_invalid.ecr"
end

def gen_500(env)
  env.response.status_code = 500
  error_text = "Internal server error."
  render "src/ecr/cap_invalid.ecr"
end
