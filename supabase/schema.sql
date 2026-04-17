-- Phase 2 schema + RPCs for Shared Adventures
create extension if not exists vector;

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  anon_id text not null unique,
  city text not null,
  door_text text not null,
  door_vector vector(384) not null,
  created_at timestamptz not null default now()
);

create table if not exists public.postcards (
  id bigserial primary key,
  from_id uuid not null references public.users(id) on delete cascade,
  to_id uuid not null references public.users(id) on delete cascade,
  body text not null,
  image_url text,
  city text,
  sent_at timestamptz not null default now(),
  status text not null default 'sent' check (status in ('sent', 'delivered', 'read')),
  parent_postcard_id bigint references public.postcards(id) on delete set null,
  root_postcard_id bigint references public.postcards(id) on delete set null,
  route_depth integer not null default 0,
  routed_by text not null default 'door' check (routed_by in ('door', 'reply')),
  read_at timestamptz,
  replied_at timestamptz,
  passed_at timestamptz
);

alter table public.postcards add column if not exists parent_postcard_id bigint references public.postcards(id) on delete set null;
alter table public.postcards add column if not exists root_postcard_id bigint references public.postcards(id) on delete set null;
alter table public.postcards add column if not exists route_depth integer not null default 0;
alter table public.postcards add column if not exists routed_by text not null default 'door';
alter table public.postcards add column if not exists read_at timestamptz;
alter table public.postcards add column if not exists replied_at timestamptz;
alter table public.postcards add column if not exists passed_at timestamptz;

-- Backfill existing rows (Phase 1 data)
update public.postcards
set root_postcard_id = id,
    route_depth = 0,
    routed_by = coalesce(routed_by, 'door')
where root_postcard_id is null;

create table if not exists public.postcard_events (
  id bigserial primary key,
  postcard_id bigint not null references public.postcards(id) on delete cascade,
  event_type text not null,
  actor_id uuid references public.users(id) on delete set null,
  to_id uuid references public.users(id) on delete set null,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_users_door_vector on public.users using ivfflat (door_vector vector_cosine_ops) with (lists = 100);
create index if not exists idx_postcards_to_id on public.postcards(to_id);
create index if not exists idx_postcards_root_depth on public.postcards(root_postcard_id, route_depth);
create index if not exists idx_postcards_parent on public.postcards(parent_postcard_id);
create index if not exists idx_postcard_events_postcard_id on public.postcard_events(postcard_id);

-- Recipient matching for new sends/pass-alongs.
create or replace function public.match_recipient_for_sender(p_from_user_id uuid)
returns uuid
language sql
stable
as $$
with source as (
  select id, door_vector from public.users where id = p_from_user_id
), base_candidates as (
  select
    u.id,
    u.door_vector,
    not exists (
      select 1 from public.postcards p2
      where p2.to_id = u.id
    ) as has_never_received
  from public.users u
  cross join source s
  where u.id <> s.id
    and not exists (
      select 1 from public.postcards p
      where (p.from_id = s.id and p.to_id = u.id)
         or (p.from_id = u.id and p.to_id = s.id)
    )
), selection_mode as (
  select coalesce(bool_or(has_never_received), false) as prefer_never_received
  from base_candidates
), eligible as (
  select b.*
  from base_candidates b
  cross join selection_mode m
  where (m.prefer_never_received and b.has_never_received)
     or (not m.prefer_never_received)
), ranked as (
  select
    e.id,
    row_number() over (order by e.door_vector <=> s.door_vector asc) as rank
  from eligible e
  cross join source s
), ranked_with_count as (
  select r.*, count(*) over () as candidate_count
  from ranked r
)
select id
from ranked_with_count
where (
  candidate_count >= 5 and rank between 5 and 100
) or (
  candidate_count < 5 and rank between 1 and 100
)
order by random()
limit 1;
$$;

create or replace function public.send_postcard(
  p_from_id uuid,
  p_body text,
  p_image_url text default null,
  p_city text default null,
  p_routed_by text default 'door'
)
returns public.postcards
language plpgsql
security definer
as $$
declare
  v_to_id uuid;
  v_row public.postcards;
begin
  v_to_id := public.match_recipient_for_sender(p_from_id);
  if v_to_id is null then
    raise exception 'No eligible recipient found';
  end if;

  insert into public.postcards (
    from_id, to_id, body, image_url, city, status,
    parent_postcard_id, root_postcard_id, route_depth, routed_by
  ) values (
    p_from_id, v_to_id, p_body, p_image_url, p_city, 'sent',
    null, null, 0, coalesce(p_routed_by, 'door')
  )
  returning * into v_row;

  update public.postcards
  set root_postcard_id = v_row.id
  where id = v_row.id
  returning * into v_row;

  insert into public.postcard_events(postcard_id, event_type, actor_id, to_id)
  values (v_row.id, 'sent', p_from_id, v_to_id);

  return v_row;
end;
$$;

create or replace function public.reply_postcard(
  p_parent_postcard_id bigint,
  p_from_id uuid,
  p_body text,
  p_image_url text default null,
  p_city text default null
)
returns public.postcards
language plpgsql
security definer
as $$
declare
  v_parent public.postcards;
  v_row public.postcards;
begin
  select * into v_parent
  from public.postcards
  where id = p_parent_postcard_id;

  if not found then
    raise exception 'Parent postcard not found';
  end if;

  if v_parent.to_id <> p_from_id then
    raise exception 'Only recipient can reply to this postcard';
  end if;

  insert into public.postcards (
    from_id, to_id, body, image_url, city, status,
    parent_postcard_id, root_postcard_id, route_depth, routed_by
  ) values (
    p_from_id, v_parent.from_id, p_body, p_image_url, p_city, 'sent',
    v_parent.id,
    coalesce(v_parent.root_postcard_id, v_parent.id),
    coalesce(v_parent.route_depth, 0) + 1,
    'reply'
  )
  returning * into v_row;

  update public.postcards
  set replied_at = now(), read_at = coalesce(read_at, now())
  where id = v_parent.id;

  insert into public.postcard_events(postcard_id, event_type, actor_id, to_id, meta)
  values (v_row.id, 'reply', p_from_id, v_parent.from_id, jsonb_build_object('parent_postcard_id', v_parent.id));

  return v_row;
end;
$$;

create or replace function public.pass_postcard(
  p_parent_postcard_id bigint,
  p_from_id uuid,
  p_body text,
  p_image_url text default null,
  p_city text default null
)
returns public.postcards
language plpgsql
security definer
as $$
declare
  v_parent public.postcards;
  v_row public.postcards;
  v_to_id uuid;
begin
  select * into v_parent
  from public.postcards
  where id = p_parent_postcard_id;

  if not found then
    raise exception 'Parent postcard not found';
  end if;

  if v_parent.to_id <> p_from_id then
    raise exception 'Only recipient can pass this postcard along';
  end if;

  v_to_id := public.match_recipient_for_sender(p_from_id);
  if v_to_id is null then
    raise exception 'No eligible recipient found for pass-along';
  end if;

  insert into public.postcards (
    from_id, to_id, body, image_url, city, status,
    parent_postcard_id, root_postcard_id, route_depth, routed_by
  ) values (
    p_from_id, v_to_id, p_body, p_image_url, p_city, 'sent',
    v_parent.id,
    coalesce(v_parent.root_postcard_id, v_parent.id),
    coalesce(v_parent.route_depth, 0) + 1,
    'door'
  )
  returning * into v_row;

  update public.postcards
  set passed_at = now(), read_at = coalesce(read_at, now())
  where id = v_parent.id;

  insert into public.postcard_events(postcard_id, event_type, actor_id, to_id, meta)
  values (v_row.id, 'pass', p_from_id, v_to_id, jsonb_build_object('parent_postcard_id', v_parent.id));

  return v_row;
end;
$$;

create or replace function public.get_inbox(p_user_id uuid)
returns table (
  id bigint,
  from_id uuid,
  to_id uuid,
  body text,
  image_url text,
  city text,
  sent_at timestamptz,
  status text,
  parent_postcard_id bigint,
  root_postcard_id bigint,
  route_depth integer,
  routed_by text,
  read_at timestamptz,
  replied_at timestamptz,
  passed_at timestamptz,
  from_city text,
  from_anon_id text
)
language sql
stable
as $$
  select
    p.id,
    p.from_id,
    p.to_id,
    p.body,
    p.image_url,
    p.city,
    p.sent_at,
    p.status,
    p.parent_postcard_id,
    p.root_postcard_id,
    p.route_depth,
    p.routed_by,
    p.read_at,
    p.replied_at,
    p.passed_at,
    u.city as from_city,
    u.anon_id as from_anon_id
  from public.postcards p
  join public.users u on u.id = p.from_id
  where p.to_id = p_user_id
  order by p.sent_at desc;
$$;

create or replace function public.get_route(p_root_postcard_id bigint)
returns table (
  id bigint,
  parent_postcard_id bigint,
  root_postcard_id bigint,
  route_depth integer,
  from_id uuid,
  to_id uuid,
  from_city text,
  to_city text,
  body text,
  city text,
  sent_at timestamptz,
  routed_by text
)
language sql
stable
as $$
  select
    p.id,
    p.parent_postcard_id,
    p.root_postcard_id,
    p.route_depth,
    p.from_id,
    p.to_id,
    fu.city as from_city,
    tu.city as to_city,
    p.body,
    p.city,
    p.sent_at,
    p.routed_by
  from public.postcards p
  join public.users fu on fu.id = p.from_id
  join public.users tu on tu.id = p.to_id
  where p.root_postcard_id = p_root_postcard_id
  order by p.route_depth asc, p.sent_at asc;
$$;

-- Prototype mode: simple open access; lock down with RLS in Phase 3.
alter table public.users disable row level security;
alter table public.postcards disable row level security;
alter table public.postcard_events disable row level security;
