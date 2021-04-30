post "/cap/:cap_slug/poll/vote" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])
  fail(403, "Unauthorized.") if cap_data.nil? || (cap_data.kind != CapKind::PollVote && cap_data.kind != CapKind::PollAdmin)

  name, password, vote, reason = HTML.escape(env.params.body["name"].as(String)), HTML.escape(env.params.body["password"].as(String)), env.params.body["vote"].as(String), HTML.escape(env.params.body["reason"].as(String))
  validate_checks(
    validate_username(name),
    validate_reason(reason),
    validate_password(password)
  )

  old_vote = DATABASE.query_all("select * from votes where poll_id = ? and username = ?", cap_data.poll_id, name, as: Vote)[0]?

  if vote == "delvote"
    if old_vote
      fail(403, "Invalid Password.") unless valid_password(:poll, cap_data.poll_id, name, password)

      DATABASE.exec "delete from votes where poll_id = ? and username = ?", cap_data.poll_id, name
      Log.info &.emit("deleted poll vote", id: cap_data.poll_id, cap: cap_data.cap_slug, name: name)
    else
      fail(400, "You can't delete your vote if it hasn't been set before.")
    end
  else
    vote = VoteKind.parse(vote)

    if old_vote
      fail(403, "Invalid Password.") unless valid_password(:poll, cap_data.poll_id, name, password)

      DATABASE.exec(
        "update votes set kind = ?, reason = ?, created_at = current_timestamp where poll_id = ? and username = ?",
        vote.value,
        reason,
        cap_data.poll_id,
        name
      )
      Log.info &.emit("updated poll vote", id: cap_data.poll_id, cap: cap_data.cap_slug, name: name)
    else
      DATABASE.exec(
        "insert into votes (kind, username, password, reason, poll_id) values (?,?,?,?,?)",
        vote.value,
        name,
        Crypto::Bcrypt::Password.create(password).to_s,
        reason,
        cap_data.poll_id
      )
      Log.info &.emit("created poll vote", id: cap_data.poll_id, cap: cap_data.cap_slug, name: name)
    end
  end

  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end

get "/cap/:cap_slug/poll/end_voting" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])
  fail(403, "Unauthorized.") if cap_data.nil? || cap_data.kind != CapKind::PollAdmin

  DATABASE.exec("update caps set kind = 3 where kind = 4 and poll_id = ?", cap_data.poll_id)
  Log.info &.emit("closed poll", id: cap_data.poll_id, cap: cap_data.cap_slug)

  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end

post "/cap/:cap_slug/poll/update" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])
  fail(403, "Unauthorized") if cap_data.nil? || cap_data.kind != CapKind::PollAdmin

  title, description = HTML.escape(env.params.body["title"].as(String)), HTML.escape(env.params.body["description"].as(String))
  validate_checks(
    validate_title(title),
    validate_content(description)
  )

  DATABASE.exec("update polls set title = ?, description = ? where id = ?", title, description, cap_data.poll_id)
  Log.info &.emit("updated poll", id: cap_data.poll_id, cap: cap_data.cap_slug)

  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end
