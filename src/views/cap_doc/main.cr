def gen_doc(cap)
  doc = DATABASE.query_all("select * from docs where id = ?", cap.doc_id, as: Doc)[0]

  revisions = DATABASE.query_all(
    "select * from doc_revisions where doc_id = ?",
    doc.id,
    as: DocRevision
  )
  reactions = DATABASE.query_all("select * from doc_revision_reactions where doc_id = ?", doc.id, as: DocRevisionReaction)

  # get all caps with "lower" kind than this one
  lower_caps = DATABASE.query_all(
    "select cap_slug, kind from caps where doc_id = ? and kind <= ? and kind >= ?",
    cap.doc_id,
    cap.kind_val,
    CapKind::DocView.value,
    as: Cap
  )

  tov_render "cap_doc"
end
