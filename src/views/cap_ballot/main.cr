def gen_ballot(cap)
  ballot = DATABASE.query_all("select * from ballots where id = ?", cap.ballot_id, as: Ballot)[0]
  og_desc = ""
  case cap.kind
  when CapKind::BallotAdmin
    og_desc = "You were supposed to keep this link private, s m h"
  when CapKind::BallotVote
    og_desc = "Cast your vote in this ballot on Tug of Vote"
  else
    og_desc = "View this ballot on Tug of Vote"
  end

  if (
       ballot.duration &&
       (cap.kind == CapKind::BallotVote || cap.kind == CapKind::BallotAdmin) &&
       Time.parse_utc(ballot.created_at, "%F %H:%M:%S") + Time::Span.new(ballot.duration.not_nil!, 0, 0) <= Time.utc
     )
    DATABASE.exec("update caps set kind = 9 where kind = 10 and ballot_id = ?", cap.ballot_id)
    LOG.info("ballot##{cap.ballot_id}: #{cap.cap_slug} auto-closed voting")
    if cap.kind == CapKind::BallotVote
      cap.kind = CapKind::BallotVoteDisabled
      gen_ballot(cap)
    end
  end

  close_timestamp = nil
  if ballot.duration
    close_timestamp = (Time.parse_utc(ballot.created_at, "%F %H:%M:%S") + Time::Span.new(ballot.duration.not_nil!, 0, 0)).to_unix_ms
  end

  votes = DATABASE.query_all("select * from ballot_votes where ballot_id = ?", cap.ballot_id, as: BallotVote)
  lower_caps = DATABASE.query_all("select * from caps where ballot_id = ? and kind <= ? and kind > ?", cap.ballot_id, cap.kind_val, CapKind::Revoked.value, as: Cap)

  tov_render "cap_ballot"
end
