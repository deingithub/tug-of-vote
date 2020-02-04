def gen_poll(cap)
  og_desc = ""
  case cap.kind
  when CapKind::PollAdmin
    og_desc = "You were supposed to keep this link private, s m h"
  when CapKind::PollVote
    og_desc = "Participate in this poll on Tug of Vote"
  else
    og_desc = "View this poll on Tug of Vote"
  end
  poll = DATABASE.query_all("select * from polls where id = ?", cap.poll_id, as: Poll)[0]

  if (
       poll.duration &&
       (cap.kind == CapKind::PollVote || cap.kind == CapKind::PollAdmin) &&
       Time.parse_utc(poll.created_at, "%F %H:%M:%S") + Time::Span.new(poll.duration.not_nil!, 0, 0) <= Time.utc
     )
    DATABASE.exec("update caps set kind = 3 where kind = 4 and poll_id = ?", cap.poll_id)
    LOG.info("poll##{cap.poll_id}: #{cap.cap_slug} auto-closed voting")
    if cap.kind == CapKind::PollVote
      cap.kind = CapKind::PollVoteDisabled
      gen_poll(cap)
    end
  end

  votes = DATABASE.query_all("select * from votes where poll_id = ?", cap.poll_id, as: Vote)
  lower_caps = DATABASE.query_all("select * from caps where poll_id = ? and kind <= ? and kind > ?", cap.poll_id, cap.kind_val, CapKind::Revoked.value, as: Cap)

  pro_votes = {votes.select { |x| x.kind == VoteKind::InFavor && !x.reason.empty? }, votes.select { |x| x.kind == VoteKind::InFavor && x.reason.empty? }}
  neu_votes = {votes.select { |x| x.kind == VoteKind::Neutral && !x.reason.empty? }, votes.select { |x| x.kind == VoteKind::Neutral && x.reason.empty? }}
  con_votes = {votes.select { |x| x.kind == VoteKind::Against && !x.reason.empty? }, votes.select { |x| x.kind == VoteKind::Against && x.reason.empty? }}
  anonymize = cap.kind == CapKind::PollViewAnon
  render "src/ecr/cap_poll.ecr"
end
