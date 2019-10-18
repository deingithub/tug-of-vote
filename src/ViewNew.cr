post "/new" do |env|
  content = env.params.body["content"].as(String)
  error_text = ""
  error_text += validate_content(content)
  unless error_text.empty?
    halt env, status_code: 400, response: render "src/ecr/cap_invalid.ecr"
  end
  admin_cap = make_cap()
  DATABASE.transaction do |tx|
    c = tx.connection
    poll_id = c.exec("insert into polls (content) values (?)", content).last_insert_id
    c.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", admin_cap, CapKind::PollAdmin.value, poll_id)
    c.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", make_cap, CapKind::PollVote.value, poll_id)
    c.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", make_cap, CapKind::PollView.value, poll_id)
    c.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", make_cap, CapKind::PollViewAnon.value, poll_id)
  end

  env.response.status_code = 303
  env.response.headers.add("Location", "/cap/#{admin_cap}")
end

def make_cap
  Random::Secure.urlsafe_base64
end
