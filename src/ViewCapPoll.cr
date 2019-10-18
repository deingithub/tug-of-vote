def gen_poll(res)
  og_desc = ""
  case CapKind.from_value(res[:kind])
  when CapKind::PollAdmin
    og_desc = "You were supposed to keep this link private, s m h"
  when CapKind::PollVote
    og_desc = "Participate in this poll on Tug of Vote"
  else
    og_desc = "View this poll on Tug of Vote"
  end
  view_component = gen_view(res)
  meta_component = gen_meta(res)
  vote_component = gen_vote(res)
  admin_component = gen_admin(res)
  render "src/ecr/cap_main.ecr"
end

def gen_view(cap)
  # get the relevant poll
  poll = DATABASE.query "select created_at, description, title from polls where id = ?", cap[:poll_id] do |rs|
    rs.move_next
    # FIXME this ugly .to_s thing is necessary to avoid an exception in case the string value
    # can be interpreted as an integer, which for some reason takes precedence
    next {created_at: rs.read(String), description: rs.read.to_s, title: rs.read.to_s}
  end
  # get all votes
  votes = [] of {kind: Int64, username: String, reason: String}
  DATABASE.query "select kind, username, reason from votes where poll_id = ?", cap[:poll_id] do |rs|
    rs.each do
      # FIXME this ugly .to_s thing is necessary to avoid an exception in case the string value
      # can be interpreted as an integer, which for some reason takes precedence
      votes << {kind: rs.read(Int64), username: rs.read.to_s, reason: rs.read.to_s}
    end
  end

  votes = votes.map do |x|
    {username: x[:username], reason: x[:reason], kind: VoteKind.from_value(x[:kind])}
  end
  pro_votes = votes.select { |x| x[:kind] == VoteKind::InFavor }
  con_votes = votes.select { |x| x[:kind] == VoteKind::Against }
  neu_votes = votes.select { |x| x[:kind] == VoteKind::Neutral }
  anonymize = CapKind.from_value(cap[:kind]) == CapKind::PollViewAnon

  render "src/ecr/cap_component_view.ecr"
end

def gen_vote(cap)
  # return early if Unauthorized.
  if CapKind.from_value(cap[:kind]) != CapKind::PollVote && CapKind.from_value(cap[:kind]) != CapKind::PollAdmin
    return ""
  end
  render "src/ecr/cap_component_vote.ecr"
end

def gen_admin(cap)
  # return early if Unauthorized.
  if CapKind.from_value(cap[:kind]) != CapKind::PollAdmin
    return ""
  end
  poll_texts = DATABASE.query "select title, description from polls where id = ?", cap[:poll_id] do |rs|
    rs.move_next
    # FIXME this ugly .to_s thing is necessary to avoid an exception in case the string value
    # can be interpreted as an integer, which for some reason takes precedence
    next {title: rs.read.to_s, description: rs.read.to_s}
  end
  render "src/ecr/cap_component_admin.ecr"
end

def gen_meta(cap)
  # get the relevant poll
  poll = DATABASE.query "select created_at from polls where id = ?", cap[:poll_id] do |rs|
    rs.move_next
    next rs.read(created_at: String)
  end
  # get all caps with "lower" kind than this one
  lower_caps = [] of {cap_slug: String, kind: Int64}
  DATABASE.query "select cap_slug, kind from caps where poll_id = ? and kind <= ? and kind > 0", cap[:poll_id], cap[:kind] do |rs|
    rs.each do
      lower_caps << rs.read(cap_slug: String, kind: Int64)
    end
  end
  lower_caps = lower_caps.map do |x|
    {cap_slug: x[:cap_slug], kind: x[:kind], kind_str: CapKind.from_value(x[:kind]).to_s}
  end
  render "src/ecr/cap_component_meta.ecr"
end
