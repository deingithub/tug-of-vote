get "/cap/:cap_slug" do |env|
  rs = DATABASE.query "select poll_id, kind, cap_slug from caps where cap_slug = ?", env.params.url["cap_slug"]
  begin
    if rs.move_next
      result = rs.read(poll_id: Int64, kind: Int64, cap_slug: String)
      rs.close
      if CapKind.from_value(result[:kind]) == CapKind::Revoked
        next gen_404(env)
      else
        next gen_result(result)
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

def gen_result(res)
  og_desc = ""
  case CapKind.from_value(res[:kind])
  when CapKind::Admin
    og_desc = "You were supposed to keep this link private, s m h"
  when CapKind::Vote
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
  poll = DATABASE.query "select created_at, content from polls where id = ?", cap[:poll_id] do |rs|
    rs.move_next
    # FIXME this ugly .to_s thing is necessary to avoid an exception in case the string value
    # can be interpreted as an integer, which for some reason takes precedence
    next {created_at: rs.read(String), content: rs.read.to_s}
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
  anonymize = CapKind.from_value(cap[:kind]) == CapKind::ViewAnon

  render "src/ecr/cap_component_view.ecr"
end

def gen_vote(cap)
  # return early if Unauthorized.
  if CapKind.from_value(cap[:kind]) != CapKind::Vote && CapKind.from_value(cap[:kind]) != CapKind::Admin
    return ""
  end
  render "src/ecr/cap_component_vote.ecr"
end

def gen_admin(cap)
  # return early if Unauthorized.
  if CapKind.from_value(cap[:kind]) != CapKind::Admin
    return ""
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
