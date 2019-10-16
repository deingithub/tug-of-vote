post "/new" do |env|
  content = env.params.body["content"].as(String)
  if content.empty?
    halt env, status_code: 400, response: "Content may not be empty"
  end
  if content.size > 20000
    halt env, status_code: 400, response: "Maximum content length is 20000 characters"
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