require "./cap_poll/main"
require "./cap_poll/actions"
require "./cap_list/main"
require "./cap_list/actions"

get "/cap/:cap_slug" do |env|
  cap = fetch_cap(env.params.url["cap_slug"])
  if cap
    case cap.kind
    when CapKind::Revoked
      next gen_404(env)
    when CapKind::ListView, CapKind::ListAdmin
      next gen_list(cap)
    when CapKind::PollAdmin, CapKind::PollVote, CapKind::PollVoteDisabled, CapKind::PollView, CapKind::PollViewAnon
      next gen_poll(cap)
    else
      raise "Unimplemented CapKind"
    end
  else
    next gen_404(env)
  end
end

def gen_404(env)
  env.response.status_code = 404
  error_text = "This URL is unknown, invalid or has been revoked. Sorry."
  tov_render "cap_invalid"
end
