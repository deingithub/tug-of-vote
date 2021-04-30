NO_VOTES = [] of Vote

def gen_poll(cap)
  og_desc = case cap.kind
            when CapKind::PollAdmin
              "You were supposed to keep this link private, s m h"
            when CapKind::PollVote
              "Participate in this poll on Tug of Vote"
            else
              "View this poll on Tug of Vote"
            end

  poll = DATABASE.query_all("select * from polls where id = ?", cap.poll_id, as: Poll)[0]

  if (
       poll.duration &&
       (cap.kind == CapKind::PollVote || cap.kind == CapKind::PollAdmin) &&
       (poll.created_at + poll.duration.not_nil!) <= Time.utc
     )
    DATABASE.exec("update caps set kind = 3 where kind = 4 and poll_id = ?", cap.poll_id)
    Log.info &.emit("auto-closed poll", id: cap.ballot_id, slug: cap.cap_slug)

    if cap.kind == CapKind::PollVote
      cap.kind = CapKind::PollVoteDisabled
      gen_poll(cap)
    end
  end

  close_timestamp = nil
  close_timestamp = (poll.created_at + poll.duration.not_nil!).to_unix_ms if poll.duration
  anonymize = cap.kind == CapKind::PollViewAnon
  lower_caps = DATABASE.query_all("select * from caps where poll_id = ? and kind <= ? and kind > ?", cap.poll_id, cap.kind_val, CapKind::Revoked.value, as: Cap)

  votes = DATABASE.query_all("select * from votes where poll_id = ?", cap.poll_id, as: Vote)

  pro_votes = votes.select { |v| v.kind == VoteKind::InFavor }.group_by { |v| v.reason.empty? }
  pro_votes = {pro_votes[false]? || NO_VOTES, pro_votes[true]? || NO_VOTES}

  neu_votes = votes.select { |v| v.kind == VoteKind::Neutral }.group_by { |v| v.reason.empty? }
  neu_votes = {neu_votes[false]? || NO_VOTES, neu_votes[true]? || NO_VOTES}

  con_votes = votes.select { |v| v.kind == VoteKind::Against }.group_by { |v| v.reason.empty? }
  con_votes = {con_votes[false]? || NO_VOTES, con_votes[true]? || NO_VOTES}

  tov_render "cap_poll"
end
