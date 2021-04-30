post "/cap/:cap_slug/doc/edit" do |env|
  cap = fetch_cap(env.params.url["cap_slug"])
  fail(403, "Unauthorized.") if cap.nil? || cap.kind != CapKind::DocEdit

  name, password, comment = HTML.escape(env.params.body["name"].as(String)), HTML.escape(env.params.body["password"].as(String)), HTML.escape(env.params.body["comment"].as(String))

  new_rev, parent_rev_id = env.params.body["new-rev"].as(String), env.params.body["parent-rev"].as(String)
  new_rev = new_rev.empty? ? nil : HTML.escape(new_rev)
  parent_rev = parent_rev_id.empty? ? nil : parent_rev_id.to_i

  fail(403, "Invalid Password.") unless valid_password(:doc, cap.doc_id, name, password)
  validate_checks(
    validate_username(name),
    validate_password(password),
    validate_content(comment),
    validate_content(new_rev || "text that passes validation in case we attached no diff")
  )

  DATABASE.transaction do |trans|
    c = trans.connection
    revision_count = c.scalar("select count(*) from doc_revisions where doc_id = ?", cap.doc_id).as(Int64)

    parent_text = ""
    parent_text = rev_text(c.query_one(
      "select * from doc_revisions where doc_id = ? and id = ?",
      cap.doc_id, parent_rev, as: DocRevision
    )) if parent_rev

    diff = nil
    diff = diff(parent_text, new_rev) if new_rev

    c.exec(
      "insert or ignore into doc_users (doc_id, username, password) values (?,?,?)",
      cap.doc_id, name, Crypto::Bcrypt::Password.create(password).to_s
    )
    c.exec(
      "insert into doc_revisions (doc_id, id, username, comment, revision_diff, parent_revision_id) values (?,?,?,?,?,?)",
      cap.doc_id, revision_count + 1, name, comment, diff ? diff.to_json : nil, parent_rev
    )
  end

  Log.info &.emit("created doc revision", id: cap.doc_id, cap: cap.cap_slug, username: name)
  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end

post "/cap/:cap_slug/doc/react" do |env|
  cap = fetch_cap(env.params.url["cap_slug"])
  fail(403, "Unauthorized.") if cap.nil? || cap.kind != CapKind::DocEdit

  name, password, reaction, rev_id = HTML.escape(env.params.body["name"].as(String)), HTML.escape(env.params.body["password"].as(String)), VoteKind.parse(env.params.body["react"].as(String)), env.params.body["rev-id"].to_i

  fail(403, "Invalid Password.") unless valid_password(:doc, cap.doc_id, name, password)
  validate_checks(
    validate_username(name),
    validate_password(password)
  )

  old_reaction = DATABASE.query_all(
    "select * from doc_revision_reactions where doc_id = ? and revision_id = ? and username = ?",
    cap.doc_id, rev_id, name,
    as: DocRevisionReaction
  )[0]?

  if old_reaction
    # delete if we get the same reaction again
    if reaction == old_reaction.kind
      DATABASE.exec(
        "delete from doc_revision_reactions where doc_id = ? and revision_id = ? and username = ?",
        cap.doc_id, rev_id, name
      )
      Log.info &.emit("deleted doc revision reaction", id: cap.doc_id, cap: cap.cap_slug, revision_id: rev_id, username: name)
    else
      DATABASE.exec(
        "update doc_revision_reactions set kind = ? where doc_id = ? and revision_id = ? and username = ?",
        reaction.value, cap.doc_id, rev_id, name
      )
      Log.info &.emit("updated doc revision reaction", id: cap.doc_id, cap: cap.cap_slug, revision_id: rev_id, username: name)
    end
  else
    DATABASE.transaction do |trans|
      trans.connection.exec(
        "insert or ignore into doc_users (doc_id, username, password) values (?,?,?)",
        cap.doc_id, name, Crypto::Bcrypt::Password.create(password).to_s
      )
      trans.connection.exec(
        "insert into doc_revision_reactions (doc_id, revision_id, username, kind) values (?,?,?,?)",
        cap.doc_id, rev_id, name, reaction.value
      )
    end

    Log.info { "doc##{cap.doc_id}: #{cap.cap_slug} created reaction on #{rev_id} #{name}" }
  end

  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end

get "/cap/:cap_slug/doc/revs/:rev_id" do |env|
  cap = fetch_cap(env.params.url["cap_slug"])
  fail(403, "Unauthorized.") if cap.nil? || (cap.kind != CapKind::DocEdit && cap.kind != CapKind::DocView)

  doc = DATABASE.query_all("select * from docs where id = ?", cap.doc_id, as: Doc)[0]

  rev = DATABASE.query_all(
    "select * from doc_revisions where doc_id = ? and id = ?",
    doc.id,
    env.params.url["rev_id"].to_i,
    as: DocRevision
  )[0]

  next tov_render "cap_doc_rev"
end
