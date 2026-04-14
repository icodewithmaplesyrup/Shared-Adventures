-- Phase 1 vertical slice schema for Shared Adventures
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
  status text not null default 'sent' check (status in ('sent', 'delivered', 'read'))
);

create index if not exists idx_users_door_vector on public.users using ivfflat (door_vector vector_cosine_ops) with (lists = 100);
create index if not exists idx_postcards_to_id on public.postcards(to_id);

-- Returns one recipient id for sender:
-- 1) nearest semantic neighbors (cosine distance)
-- 2) skip top 4 nearest neighbors, sample rank 5..100
-- 3) only users who have not received a postcard yet
-- 4) avoid same pair match in either direction
create or replace function public.match_recipient_for_sender(p_from_user_id uuid)
returns uuid
language sql
stable
as $$
with source as (
  select id, door_vector from public.users where id = p_from_user_id
), ranked as (
  select
    u.id,
    row_number() over (order by u.door_vector <=> s.door_vector asc) as rank
  from public.users u
  cross join source s
  where u.id <> s.id
    and not exists (
      select 1 from public.postcards p
      where (p.from_id = s.id and p.to_id = u.id)
         or (p.from_id = u.id and p.to_id = s.id)
    )
    and not exists (
      select 1 from public.postcards p2
      where p2.to_id = u.id
    )
)
select id
from ranked
where rank between 5 and 100
order by random()
limit 1;
$$;

-- Prototype mode: simple open access; lock down with RLS in Phase 3.
alter table public.users disable row level security;
alter table public.postcards disable row level security;
