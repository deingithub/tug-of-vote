# TODO editing
post "/cap/:cap_slug/doc/edit" do |env|
  cap = fetch_cap(env.params.url["cap_slug"])
  if cap.nil? || cap.kind != CapKind::DocEdit
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: tov_render "cap_invalid"
  end

  name = HTML.escape(env.params.body["name"].as(String))
  password = HTML.escape(env.params.body["password"].as(String))
  comment = HTML.escape(env.params.body["comment"].as(String))
  new_rev_s = env.params.body["new-rev"].as(String)
  parent_rev_id_s = env.params.body["parent-rev"].as(String)
  new_rev = new_rev_s.empty? ? nil : HTML.escape(new_rev_s)
  parent_rev = parent_rev_id_s.empty? ? nil : parent_rev_id_s.to_i

  error_text = ""
  error_text += validate_username(name)
  error_text += validate_password(password)
  error_text += validate_content(comment)
  error_text += validate_content(new_rev || "text that passes validation in case we attached no diff")
  unless error_text.empty?
    halt env, status_code: 400, response: tov_render "cap_invalid"
  end
  unless valid_password(:doc, cap.doc_id, name, password)
    error_text = "Invalid Password. "
    halt env, status_code: 403, response: tov_render "cap_invalid"
  end

  DATABASE.transaction do |trans|
    revision_count = trans.connection.scalar(
      "select count(*) from doc_revisions where doc_id = ?",
      cap.doc_id
    ).as(Int64)
    parent_text = if parent_rev
                    rev_text(
                      DATABASE.query_one(
                        "select * from doc_revisions where doc_id = ? and id = ?",
                        cap.doc_id, parent_rev, as: DocRevision
                      )
                    )
                  else
                    ""
                  end
    diff = if new_rev
             diff(parent_text, new_rev)
           else
             nil
           end
    trans.connection.exec(
      "insert or ignore into doc_users (doc_id, username, password) values (?,?,?)",
      cap.doc_id, name, Crypto::Bcrypt::Password.create(password).to_s
    )
    trans.connection.exec(
      "insert into doc_revisions (doc_id, id, username, comment, revision_diff, parent_revision_id) values (?,?,?,?,?,?)",
      cap.doc_id, revision_count + 1, name, comment, diff ? diff.to_json : nil, parent_rev
    )
  end
  LOG.info("doc##{cap.doc_id}: #{cap.cap_slug} created new revision")
  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end

post "/cap/:cap_slug/doc/react" do |env|
  cap = fetch_cap(env.params.url["cap_slug"])
  if cap.nil? || cap.kind != CapKind::DocEdit
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: tov_render "cap_invalid"
  end

  name = HTML.escape(env.params.body["name"].as(String))
  password = HTML.escape(env.params.body["password"].as(String))
  reaction = VoteKind.parse(HTML.escape(env.params.body["react"].as(String)))
  rev_id = env.params.body["rev-id"].to_i

  error_text = ""
  error_text += validate_username(name)
  error_text += validate_password(password)
  unless error_text.empty?
    halt env, status_code: 400, response: tov_render "cap_invalid"
  end

  reacts = DATABASE.query_all(
    "select * from doc_revision_reactions where doc_id = ? and revision_id = ? and username = ?",
    cap.doc_id, rev_id, name,
    as: DocRevisionReaction
  )
  unless valid_password(:doc, cap.doc_id, name, password)
    error_text = "Invalid Password. "
    halt env, status_code: 403, response: tov_render "cap_invalid"
  end

  if update_react = reacts[0]?
    if reaction == update_react.kind
      DATABASE.exec(
        "delete from doc_revision_reactions where doc_id = ? and revision_id = ? and username = ?",
        cap.doc_id, rev_id, name
      )
      LOG.info("doc##{cap.doc_id}: #{cap.cap_slug} deleted reaction on #{rev_id} #{name}")
    else
      DATABASE.exec(
        "update doc_revision_reactions set kind = ? where doc_id = ? and revision_id = ? and username = ?",
        reaction.value, cap.doc_id, rev_id, name
      )
      LOG.info("doc##{cap.doc_id}: #{cap.cap_slug} updated reaction on #{rev_id} #{name}")
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
    LOG.info("doc##{cap.doc_id}: #{cap.cap_slug} created reaction on #{rev_id} #{name}")
  end

  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end

get "/cap/:cap_slug/doc/revs/:rev_id" do |env|
  cap = fetch_cap(env.params.url["cap_slug"])
  if cap.nil? || (cap.kind != CapKind::DocEdit && cap.kind != CapKind::DocView)
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: tov_render "cap_invalid"
  end

  doc = DATABASE.query_all("select * from docs where id = ?", cap.doc_id, as: Doc)[0]

  rev = DATABASE.query_all(
    "select * from doc_revisions where doc_id = ? and id = ?",
    doc.id,
    env.params.url["rev_id"].to_i,
    as: DocRevision
  )[0]
  next tov_render "cap_doc_rev"
end
