post "/new" do |env|
  content = env.params.body["content"].as(String)
  error_text = ""
  error_text += validate_content(content)
  unless error_text.empty?
    halt env, status_code: 400, response: render "src/ecr/cap_invalid.ecr"
  end
  admin_cap = make_cap()
  poll_id = DATABASE.exec("insert into polls (content) values (?)", content).last_insert_id
  DATABASE.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", admin_cap, CapKind::Admin.value, poll_id)
  DATABASE.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", make_cap, CapKind::Vote.value, poll_id)
  DATABASE.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", make_cap, CapKind::View.value, poll_id)
  DATABASE.exec("insert into caps (cap_slug, kind, poll_id) values (?,?,?)", make_cap, CapKind::ViewAnon.value, poll_id)

  env.response.status_code = 303
  env.response.headers.add("Location", "/cap/#{admin_cap}")
end

def make_cap
  Random::Secure.urlsafe_base64
end
