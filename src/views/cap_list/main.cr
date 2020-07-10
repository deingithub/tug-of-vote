def gen_list(cap)
  list = DATABASE.query_all("select * from lists where id = ?", cap.list_id, as: List)[0]
  entries = DATABASE.query_all(
    "select * from list_entries where list_id = ?",
    cap.list_id,
    as: ListEntry
  )

  raw_caps = [] of Cap
  entries.each do |entry|
    raw_caps += DATABASE.query_all("select * from caps where cap_slug = ?", entry.cap_slug, as: Cap)
  end
  caps = raw_caps.map do |cap|
    if cap.list_id
      my_list = DATABASE.query_all("select * from lists where id = ?", cap.list_id, as: List)[0]
      next {cap, my_list}
    elsif cap.poll_id
      poll = DATABASE.query_all("select * from polls where id = ?", cap.poll_id, as: Poll)[0]
      next {cap, poll}
    elsif cap.ballot_id
      ballot = DATABASE.query_all("select * from ballots where id = ?", cap.ballot_id, as: Ballot)[0]
      next {cap, ballot}
    elsif cap.doc_id
      doc = DATABASE.query_all("select * from docs where id = ?", cap.doc_id, as: Doc)[0]
      next {cap, doc}
    else
      raise "Unreachable"
    end
  end

  # get all caps with "lower" kind than this one
  lower_caps = DATABASE.query_all(
    "select cap_slug, kind from caps where list_id = ? and kind <= ? and kind > ?",
    cap.list_id,
    cap.kind_val,
    CapKind::PollAdmin.value,
    as: Cap
  )

  tov_render "cap_list"
end
