post "/new" do |env|
  title = HTML.escape(env.params.body["title"].as(String))
  description = HTML.escape(env.params.body["description"].as(String))

  duration = nil
  begin
    duration = env.params.body["duration"].to_i
  rescue e
  end

  error_text = ""
  error_text += validate_title(title)
  error_text += validate_content(description)
  error_text += validate_duration(duration)
  unless error_text.empty?
    halt env, status_code: 400, response: tov_render "cap_invalid"
  end

  admin_cap = make_cap()
  vote_cap = make_cap()
  DATABASE.transaction do |tx|
    c = tx.connection
    poll_id = c.exec("insert into polls (title, description, duration) values (?, ?, ?)", title, description, duration).last_insert_id
    c.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", admin_cap, CapKind::PollAdmin.value, poll_id)
    c.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", vote_cap, CapKind::PollVote.value, poll_id)
    c.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", make_cap, CapKind::PollView.value, poll_id)
    c.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", make_cap, CapKind::PollViewAnon.value, poll_id)
    LOG.info("poll##{poll_id}: #{admin_cap} created")
  end

  list_param = env.params.body["listcap"]?
  if list_param
    list_cap = fetch_cap(list_param)
    if list_cap && list_cap.kind == CapKind::ListAdmin
      DATABASE.exec("insert into list_entries (cap_slug, list_id) values (?,?)", vote_cap, list_cap.list_id)
      LOG.info("list##{list_cap.list_id}: #{list_cap.cap_slug} added entry #{vote_cap}")
      spawn notify_list_addition(list_cap.list_id, vote_cap)
    end
  end

  env.response.status_code = 303
  env.response.headers.add("Location", "/cap/#{admin_cap}")
end

post "/new_list" do |env|
  title = HTML.escape(env.params.body["title"].as(String))
  description = HTML.escape(env.params.body["description"].as(String))
  error_text = ""
  error_text += validate_title(title)
  error_text += validate_content(description)
  unless error_text.empty?
    halt env, status_code: 400, response: tov_render "cap_invalid"
  end
  admin_cap = make_cap()
  DATABASE.transaction do |tx|
    c = tx.connection
    list_id = c.exec("insert into lists (title, description) values (?, ?)", title, description).last_insert_id
    c.exec("insert into caps (cap_slug, kind, list_id) values (?,?,?)", admin_cap, CapKind::ListAdmin.value, list_id)
    c.exec("insert into caps (cap_slug, kind, list_id) values (?,?,?)", make_cap, CapKind::ListView.value, list_id)
    LOG.info("list##{list_id}: #{admin_cap} created")
  end

  env.response.status_code = 303
  env.response.headers.add("Location", "/cap/#{admin_cap}")
end

def make_cap
  Random::Secure.urlsafe_base64
end
