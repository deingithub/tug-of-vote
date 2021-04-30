create table if not exists polls (
  id integer primary key,
  created_at date default current_timestamp,
  title text not null,
  description text not null,
  duration integer default null
);

create table if not exists lists (
  id integer primary key,
  created_at date default current_timestamp,
  description text not null,
  title text not null,
  webhook_url text not null default ""
);

create table if not exists list_entries (
  list_id integer not null,
  cap_slug text not null,
  foreign key (list_id) references lists(id),
  foreign key (cap_slug) references caps(cap_slug)
);

create table if not exists caps (
  cap_slug text primary key,
  kind integer not null,
  poll_id integer,
  list_id integer,
  ballot_id integer,
  doc_id integer,
  foreign key (poll_id) references polls(id),
  foreign key (list_id) references lists(id),
  foreign key (ballot_id) references ballots(id),
  foreign key (doc_id) references docs(id),
  constraint "Exactly one foreign key" check (
    (not poll_id is null and list_id is null and ballot_id is null and doc_id is null) or
    (poll_id is null and not list_id is null and ballot_id is null and doc_id is null) or
    (poll_id is null and list_id is null and not ballot_id is null and doc_id is null) or
    (poll_id is null and list_id is null and ballot_id is null and not doc_id is null)
  )
);

create table if not exists votes (
  kind integer not null,
  username text not null,
  password text not null,
  created_at date default current_timestamp,
  reason text,
  poll_id integer not null,
  foreign key (poll_id) references polls(id)
);

create table if not exists ballots (
  id integer primary key,
  created_at date default current_timestamp,
  title text not null,
  candidates text not null,
  duration integer default null,
  cached_result text not null,
  hide_names bool not null
);

create table if not exists ballot_votes (
  ballot_id integer not null,
  created_at date default current_timestamp,
  username text not null,
  password text not null,
  preferences text not null,
  foreign key (ballot_id) references ballots(id)
);

create table if not exists docs (
  id integer primary key,
  created_at date default current_timestamp,
  title text not null
);

create table if not exists doc_users (
  doc_id integer not null,
  username text not null,
  password text not null,
  foreign key (doc_id) references docs(id),
  constraint "unique usernames" unique(doc_id, username)
);

create table if not exists doc_revisions (
  id integer not null,
  doc_id integer not null,
  created_at date default current_timestamp,
  username text not null,
  comment text not null,
  revision_diff text,
  parent_revision_id integer,
  foreign key (doc_id) references docs(id),
  foreign key (doc_id, parent_revision_id) references doc_revisions(doc_id, id),
  foreign key (doc_id, username) references doc_users(doc_id, username),
  constraint "unique revision ids" unique(doc_id, id)
);

create table if not exists doc_revision_reactions (
  doc_id integer not null,
  revision_id integer not null,
  username text not null,
  kind integer not null,
  foreign key(doc_id, revision_id) references doc_revisions(doc_id, id),
  foreign key(doc_id, username) references doc_users(doc_id, username)
);
