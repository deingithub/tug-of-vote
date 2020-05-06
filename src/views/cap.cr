require "./cap_poll/main"
require "./cap_poll/actions"
require "./cap_list/main"
require "./cap_list/actions"
require "./cap_ballot/main"
require "./cap_ballot/actions"
require "./cap_doc/main"
require "./cap_doc/actions"

get "/cap/:cap_slug" do |env|
  cap = fetch_cap(env.params.url["cap_slug"])
  if cap
    case cap.kind
    when CapKind::Revoked
      error_text = "This URL is unknown, invalid or has been revoked. Sorry."
      halt env, status_code: 404, response: tov_render "cap_invalid"
      tov_render "cap_invalid"
    when CapKind::ListView, CapKind::ListAdmin
      next gen_list(cap)
    when CapKind::PollAdmin, CapKind::PollVote, CapKind::PollVoteDisabled, CapKind::PollView, CapKind::PollViewAnon
      next gen_poll(cap)
    when CapKind::BallotAdmin, CapKind::BallotVote, CapKind::BallotVoteDisabled, CapKind::BallotView
      next gen_ballot(cap)
    when CapKind::DocEdit, CapKind::DocView
      next gen_doc(cap)
    else
      raise "Unimplemented CapKind"
    end
  else
    error_text = "This URL is unknown, invalid or has been revoked. Sorry."
    halt env, status_code: 404, response: tov_render "cap_invalid"
    tov_render "cap_invalid"
  end
end
