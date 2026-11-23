-- The Bloom Series: shared gifts, cheers and wishes.
-- Paste all of this into Supabase → SQL Editor → New query, then click Run. Safe to run again.

-- 1. One table holds everything guests send
create table if not exists public.bloom_events (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  invite      text not null check (char_length(invite) <= 40),          -- which invitation, e.g. 'rose'
  kind        text not null check (kind in ('gift', 'cheer', 'wish')),
  item        text check (char_length(item) <= 40),                      -- the gift or the cheer
  name        text check (char_length(name) <= 40),                      -- wishes only
  message     text check (char_length(message) <= 240),                 -- wishes only
  client      text not null check (char_length(client) <= 40)            -- a random id per browser, used to slow down spam
);
create index if not exists bloom_events_invite_idx on public.bloom_events (invite, id desc);

-- 2. Anyone with the link can read and add, but nobody can change or delete (you can, from the dashboard)
alter table public.bloom_events enable row level security;
drop policy if exists "guests can read" on public.bloom_events;
create policy "guests can read" on public.bloom_events for select to anon, authenticated using (true);
drop policy if exists "guests can add" on public.bloom_events;
create policy "guests can add" on public.bloom_events for insert to anon, authenticated with check (
     (kind = 'gift'  and item in ('gift', 'bouquet', 'balloons', 'heart', 'cake') and name is null and message is null)
  or (kind = 'cheer' and item is not null and name is null and message is null)
  or (kind = 'wish'  and char_length(trim(coalesce(name, ''))) > 0 and char_length(trim(coalesce(message, ''))) > 0)
);

-- 3. Slow down anyone sending too much at once
create or replace function public.bloom_rate_limit() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.bloom_events where client = new.client and created_at > now() - interval '20 seconds') >= 8 then
    raise exception 'Too many in a short time. Please wait a moment.';
  end if;
  if new.kind = 'wish' and (select count(*) from public.bloom_events where client = new.client and kind = 'wish' and created_at > now() - interval '10 minutes') >= 3 then
    raise exception 'Too many wishes at once. Please wait a little.';
  end if;
  return new;
end $$;
drop trigger if exists bloom_rate_limit on public.bloom_events;
create trigger bloom_rate_limit before insert on public.bloom_events for each row execute function public.bloom_rate_limit();

-- 4. Send new rows to everyone who has the invitation open
do $$ begin
  alter publication supabase_realtime add table public.bloom_events;
exception when duplicate_object then null;
end $$;

grant select, insert on public.bloom_events to anon, authenticated;
