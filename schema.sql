create table if not exists polls (
  id integer primary key,
  created_at date default current_timestamp,
  title string not null,
  description string not null,
  duration integer default null,
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
  foreign key (poll_id) references polls(id),
  foreign key (list_id) references lists(id),
  constraint "Exactly one foreign key" check (
    (poll_id isnull) <> (list_id isnull)
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
