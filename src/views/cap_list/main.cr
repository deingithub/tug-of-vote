def gen_list(cap)
  cap_kind = CapKind.from_value(cap[:kind])
  list = DATABASE.query "select title, description, created_at from lists where id = ?", cap[:list_id].not_nil! do |rs|
    rs.move_next
    next {title: rs.read.to_s, description: rs.read.to_s, created_at: rs.read.to_s}
  end
  entries = [] of String
  DATABASE.query "select cap_slug from list_entries where list_id = ?", cap[:list_id].not_nil! do |rs|
    rs.each do
      entries << rs.read.to_s
    end
  end
  caps = [] of {cap_slug: String, kind: CapKind, list_id: Int64?, poll_id: Int64?, display_name: String}
  entries.each do |slug|
    DATABASE.query "select cap_slug, kind, list_id, poll_id from caps where cap_slug = ?", slug do |rs|
      rs.each do
        caps << {cap_slug: rs.read.to_s, kind: CapKind.from_value(rs.read(Int64)), list_id: rs.read(Int64?), poll_id: rs.read(Int64?), display_name: ""}
      end
    end
  end
  caps = caps.map do |cap|
    if cap[:list_id]
      list_title = DATABASE.query("select title from lists where id = ?", cap[:list_id]) do |rs|
        rs.move_next
        next rs.read.to_s
      end
      next cap.merge({display_name: list_title})
    elsif cap[:poll_id]
      poll_title = DATABASE.query("select title from polls where id = ?", cap[:poll_id]) do |rs|
        rs.move_next
        next rs.read.to_s
      end
      next cap.merge({display_name: poll_title})
    else
      raise "Unreachable"
    end
  end
  og_desc = "View this list on Tug of Vote"
  if cap_kind == CapKind::ListAdmin
    og_desc = "You were supposed to keep this link private, s m h"
  end

  # get all caps with "lower" kind than this one
  lower_caps = [] of {cap_slug: String, kind: Int64}
  DATABASE.query "select cap_slug, kind from caps where list_id = ? and kind <= ? and kind > ?", cap[:list_id], cap[:kind], CapKind::PollAdmin.value do |rs|
    rs.each do
      lower_caps << rs.read(cap_slug: String, kind: Int64)
    end
  end
  lower_caps = lower_caps.map do |x|
    {cap_slug: x[:cap_slug], kind: x[:kind], kind_str: CapKind.from_value(x[:kind]).to_s}
  end
  render "src/ecr/cap_list.ecr"
end
