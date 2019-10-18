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
      list = DATABASE.query_all("select * from lists where id = ?", cap.list_id, as: List)[0]
      next {cap, list}
    elsif cap.poll_id
      poll = DATABASE.query_all("select * from polls where id = ?", cap.poll_id, as: Poll)[0]
      next {cap, poll}
    else
      raise "Unreachable"
    end
  end
  og_desc = "View this list on Tug of Vote"
  if cap.kind == CapKind::ListAdmin
    og_desc = "You were supposed to keep this link private, s m h"
  end

  # get all caps with "lower" kind than this one
  lower_caps = DATABASE.query_all(
    "select cap_slug, kind from caps where list_id = ? and kind <= ? and kind > ?",
    cap.list_id,
    cap.kind_val,
    CapKind::PollAdmin.value,
    as: Cap
  )
  render "src/ecr/cap_list.ecr"
end