def gen_poll(res)
  og_desc = ""
  case res.kind
  when CapKind::PollAdmin
    og_desc = "You were supposed to keep this link private, s m h"
  when CapKind::PollVote
    og_desc = "Participate in this poll on Tug of Vote"
  else
    og_desc = "View this poll on Tug of Vote"
  end
  poll = DATABASE.query_all("select * from polls where id = ?", res.poll_id, as: Poll)[0]
  view_component = gen_view(res)
  vote_component = gen_vote(res)
  admin_component = gen_admin(res)
  render "src/ecr/cap_main.ecr"
end

def gen_view(cap)
  poll = DATABASE.query_all("select * from polls where id = ?", cap.poll_id, as: Poll)[0]
  votes = DATABASE.query_all("select * from votes where poll_id = ?", cap.poll_id, as: Vote)
  lower_caps = DATABASE.query_all("select * from caps where poll_id = ? and kind <= ? and kind > ?", cap.poll_id, cap.kind_val, CapKind::Revoked.value, as: Cap)

  pro_votes = votes.select { |x| x.kind == VoteKind::InFavor }
  con_votes = votes.select { |x| x.kind == VoteKind::Against }
  neu_votes = votes.select { |x| x.kind == VoteKind::Neutral }
  anonymize = cap.kind == CapKind::PollViewAnon

  render "src/ecr/cap_component_view.ecr"
end

def gen_vote(cap)
  # return early if unauthorized.
  if cap.kind != CapKind::PollVote && cap.kind != CapKind::PollAdmin
    return ""
  end
  render "src/ecr/cap_component_vote.ecr"
end

def gen_admin(cap)
  # return early if unauthorized.
  if cap.kind != CapKind::PollAdmin
    return ""
  end
  poll = DATABASE.query_all("select * from polls where id = ?", cap.poll_id, as: Poll)[0]
  render "src/ecr/cap_component_admin.ecr"
end
