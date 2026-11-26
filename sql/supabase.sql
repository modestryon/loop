-- Modestry On × NEOUL prototype results: one row per step of an anonymous try-on experience.
create table if not exists public.mo_events (
  id          bigint generated always as identity primary key,
  ts          timestamptz not null default now(),          -- server time (used for all reporting)
  client_ts   timestamptz,
  xid         text not null,                                -- anonymous experience id shared by both sites
  bid         text,                                         -- anonymous browser id
  env         text not null default 'prod' check (env in ('prod','test','demo')),
  site        text not null check (site in ('shop','tryon')),
  src         text not null default 'direct',               -- shop | direct | popup
  event       text not null,                                -- tryon_start | tryon_enter | wear_ok | switch_ok | detail_click | detail_arrive | order_paid | order_cancel | order_refund
  sku         text,
  prev_sku    text,
  mode        text,                                         -- camera | model
  order_id    text,
  amount      numeric,
  meta        jsonb,
  dedupe_key  text not null unique                          -- refresh / back / repeated clicks cannot add rows
);
create index if not exists mo_events_ts on public.mo_events (ts);
create index if not exists mo_events_xid on public.mo_events (xid);
alter table public.mo_events enable row level security;
-- visitors (anon key) may only add rows; they can never read, change or delete
drop policy if exists mo_insert on public.mo_events;
create policy mo_insert on public.mo_events for insert to anon, authenticated with check (char_length(xid) between 8 and 64 and char_length(event) <= 32);
-- only a signed-in admin can read
drop policy if exists mo_read on public.mo_events;
create policy mo_read on public.mo_events for select to authenticated using (true);
grant insert on public.mo_events to anon;
grant select, insert on public.mo_events to authenticated;

-- Dashboard readers: only e-mail addresses listed here can read results after signing in.
create table if not exists public.mo_admins (email text primary key);
alter table public.mo_admins enable row level security;
create or replace function public.is_mo_admin() returns boolean language sql stable security definer set search_path = public as $$ select exists (select 1 from public.mo_admins where lower(email) = lower(auth.jwt() ->> 'email')) $$;
revoke all on function public.is_mo_admin() from public;
grant execute on function public.is_mo_admin() to authenticated;
drop policy if exists mo_read on public.mo_events;
create policy mo_read on public.mo_events for select to authenticated using (public.is_mo_admin());
