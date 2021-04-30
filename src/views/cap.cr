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
    in CapKind::Revoked
      fail(404, "This URL is unknown, invalid or has been revoked. Sorry.")
    in CapKind::ListView, CapKind::ListAdmin
      next gen_list(cap)
    in CapKind::PollAdmin, CapKind::PollVote, CapKind::PollVoteDisabled, CapKind::PollView, CapKind::PollViewAnon
      next gen_poll(cap)
    in CapKind::BallotAdmin, CapKind::BallotVote, CapKind::BallotVoteDisabled, CapKind::BallotView
      next gen_ballot(cap)
    in CapKind::DocEdit, CapKind::DocView
      next gen_doc(cap)
    end
  else
    fail(404, "This URL is unknown, invalid or has been revoked. Sorry.")
  end
end
