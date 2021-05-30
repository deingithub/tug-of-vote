post "/new" do |env|
  title, description, duration = HTML.escape(env.params.body["title"].as(String)), HTML.escape(env.params.body["description"].as(String)), env.params.body["duration"].to_i?

  validate_checks(
    validate_title(title),
    validate_content(description),
    validate_duration(duration)
  )

  admin_cap = make_cap()
  vote_cap = make_cap()
  DATABASE.transaction do |trans|
    c = trans.connection
    poll_id = c.exec("insert into polls (title, description, duration) values (?, ?, ?)", title, description, duration).last_insert_id
    c.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", admin_cap, CapKind::PollAdmin.value, poll_id)
    c.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", vote_cap, CapKind::PollVote.value, poll_id)
    c.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", make_cap, CapKind::PollView.value, poll_id)
    c.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", make_cap, CapKind::PollViewAnon.value, poll_id)
    Log.info &.emit("created poll", id: poll_id, cap: admin_cap)
  end

  if list_param = env.params.body["listcap"]?
    list_cap = fetch_cap(list_param)
    if list_cap && list_cap.kind == CapKind::ListAdmin
      DATABASE.exec("insert into list_entries (cap_slug, list_id) values (?,?)", vote_cap, list_cap.list_id)
      Log.info &.emit("added list entry", id: list_cap.list_id, cap: list_cap.cap_slug, target_cap: vote_cap)

      spawn notify_list_addition(list_cap.list_id, vote_cap)
    end
  end

  env.redirect("/cap/#{admin_cap}")
end

post "/new_list" do |env|
  title, description = HTML.escape(env.params.body["title"].as(String)), HTML.escape(env.params.body["description"].as(String))
  validate_checks(
    validate_title(title),
    validate_content(description)
  )

  admin_cap = make_cap()
  DATABASE.transaction do |trans|
    c = trans.connection
    list_id = c.exec("insert into lists (title, description) values (?, ?)", title, description).last_insert_id
    c.exec("insert into caps (cap_slug, kind, list_id) values (?,?,?)", admin_cap, CapKind::ListAdmin.value, list_id)
    c.exec("insert into caps (cap_slug, kind, list_id) values (?,?,?)", make_cap, CapKind::ListView.value, list_id)
    Log.info &.emit("list created", id: list_id, cap: admin_cap)
  end

  env.redirect("/cap/#{admin_cap}")
end

post "/new_ballot" do |env|
  title, description, candidates_str, duration = HTML.escape(env.params.body["title"].as(String)), HTML.escape(env.params.body["description"].as(String)), HTML.escape(env.params.body["candidates"].as(String)), env.params.body["duration"].to_i?

  # clean up candidates: split on lines, trim whitespace, remove empties and only keep unique names
  candidates = candidates_str.split("\n").map(&.strip).reject(&.empty?).uniq.sort

  # this seems redundant, but, trust me, it is not
  hide_names = env.params.body["hide-names"]? ? true : false

  validate_checks(
    validate_title(title),
    validate_candidate_list(candidates),
    validate_duration(duration),
    validate_optional_content(description)
  )

  admin_cap = make_cap()
  vote_cap = make_cap()
  DATABASE.transaction do |trans|
    c = trans.connection
    ballot_id = c.exec(
      "insert into ballots (title, candidates, duration, cached_result, hide_names, description) values (?, ?, ?, ?, ?, ?)",
      title,
      candidates.to_json,
      duration,
      (0...candidates.size).map { |n| {n, 1} }.to_h.to_json,
      hide_names,
      description
    ).last_insert_id
    c.exec("insert into caps (cap_slug, kind, ballot_id) values (?,?,?)", admin_cap, CapKind::BallotAdmin.value, ballot_id)
    c.exec("insert into caps (cap_slug, kind, ballot_id) values (?,?,?)", vote_cap, CapKind::BallotVote.value, ballot_id)
    c.exec("insert into caps (cap_slug, kind, ballot_id) values (?,?,?)", make_cap, CapKind::BallotView.value, ballot_id)
    Log.info &.emit("ballot created", id: ballot_id, cap: admin_cap)
  end

  if list_param = env.params.body["listcap"]?
    list_cap = fetch_cap(list_param)
    if list_cap && list_cap.kind == CapKind::ListAdmin
      DATABASE.exec("insert into list_entries (cap_slug, list_id) values (?,?)", vote_cap, list_cap.list_id)
      Log.info &.emit("added list entry", id: list_cap.list_id, cap: list_cap.cap_slug, target_cap: vote_cap)

      spawn notify_list_addition(list_cap.list_id, vote_cap)
    end
  end

  env.redirect("/cap/#{admin_cap}")
end

post "/new_doc" do |env|
  title = HTML.escape(env.params.body["title"].as(String))
  validate_checks(validate_title(title))

  edit_cap = make_cap()
  DATABASE.transaction do |trans|
    c = trans.connection
    doc_id = c.exec("insert into docs (title) values (?)", title).last_insert_id
    c.exec("insert into caps (cap_slug, kind, doc_id) values (?,?,?)", edit_cap, CapKind::DocEdit.value, doc_id)
    c.exec("insert into caps (cap_slug, kind, doc_id) values (?,?,?)", make_cap, CapKind::DocView.value, doc_id)
    Log.info &.emit("created doc", id: doc_id, cap: edit_cap)
  end

  if list_param = env.params.body["listcap"]?
    list_cap = fetch_cap(list_param)
    if list_cap && list_cap.kind == CapKind::ListAdmin
      DATABASE.exec("insert into list_entries (cap_slug, list_id) values (?,?)", edit_cap, list_cap.list_id)
      Log.info &.emit("added list entry", id: list_cap.list_id, cap: list_cap.cap_slug, target_cap: edit_cap)

      spawn notify_list_addition(list_cap.list_id, edit_cap)
    end
  end

  env.redirect("/cap/#{edit_cap}")
end
