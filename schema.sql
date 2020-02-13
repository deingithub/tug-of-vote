create table if not exists polls (
  id integer primary key,
  created_at date default current_timestamp,
  title string not null,
  description string not null,
  duration integer default null
);

create table if not exists lists (
  id integer primary key,
  created_at date default current_timestamp,
  description string not null,
  title string not null,
  webhook_url string not null default ""
);

create table if not exists list_entries (
  list_id integer not null,
  cap_slug string not null,
  foreign key (list_id) references lists(id),
  foreign key (cap_slug) references caps(cap_slug)
);

create table if not exists caps (
  cap_slug string primary key,
  kind integer not null,
  poll_id integer,
  list_id integer,
  ballot_id integer,
  foreign key (poll_id) references polls(id),
  foreign key (list_id) references lists(id),
  foreign key (ballot_id) references ballots(id),
  constraint "Exactly one foreign key" check (
    (not poll_id is null and list_id is null and ballot_id is null) or
    (poll_id is null and not list_id is null and ballot_id is null) or
    (poll_id is null and list_id is null and not ballot_id is null)
  )
);

create table if not exists votes (
  kind integer not null,
  username string not null,
  password string not null,
  created_at date default current_timestamp,
  reason string,
  poll_id integer not null,
  foreign key (poll_id) references polls(id)
);

create table if not exists ballots (
  id integer primary key,
  created_at date default current_timestamp,
  title string not null,
  candidates string not null,
  duration integer default null,
  cached_result string not null
);

create table if not exists ballot_votes (
  ballot_id integer not null,
  created_at date default current_timestamp,
  username string not null,
  password string not null,
  preferences string not null,
  foreign key (ballot_id) references ballots(id)
);