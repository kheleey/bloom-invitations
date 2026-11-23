-- The Bloom Series: shared gifts, cheers and wishes.
-- Paste all of this into Supabase → SQL Editor → New query, then click Run. Safe to run again.

-- 1. One table holds everything guests send
create table if not exists public.bloom_events (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  invite      text not null check (char_length(invite) <= 40),          -- which invitation, e.g. 'rose'
  kind        text not null,                                             -- gift, cheer, wish, or reset (host only)
  item        text check (char_length(item) <= 40),                      -- the gift or the cheer
  name        text check (char_length(name) <= 40),                      -- wishes only
  message     text,                                                      -- wishes only (length checked below)
  client      text not null check (char_length(client) <= 40)            -- a random id per browser, used to slow down spam
);
create index if not exists bloom_events_invite_idx on public.bloom_events (invite, id desc);

-- 2. Anyone with the link can read and add, but nobody can change or delete (you can, from the dashboard)
alter table public.bloom_events enable row level security;
drop policy if exists "guests can read" on public.bloom_events;
create policy "guests can read" on public.bloom_events for select to anon, authenticated using (true);
drop policy if exists "guests can add" on public.bloom_events;
-- If you rename an invitation's key in index.html, change it in this list too ('test-only' is for the security test).
create policy "guests can add" on public.bloom_events for insert to anon, authenticated with check (
  invite in ('cherry-blossom', 'tulip', 'rose', 'lavender', 'sunflower', 'test-only') and (
     (kind = 'gift'  and item in ('gift', 'bouquet', 'balloons', 'heart', 'cake') and name is null and message is null)
  or (kind = 'cheer' and item in ('Congratulations!', 'Can’t wait!', 'So happy for you', 'Cheers!', 'See you there', 'With love') and name is null and message is null)
  or (kind = 'wish'  and char_length(trim(coalesce(name, ''))) > 0 and char_length(trim(coalesce(message, ''))) > 0
      -- wishes are public: no links, emails or phone numbers (11 or more digits, so dates and times are fine)
      and (name || ' | ' || message) !~* '(https?://|www\.|t\.me/|[a-z0-9-]+\.(com|net|org|cn|io|me|co|xyz|top|info|link|ly|app|site|shop|vip|cc)\y|[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,})'
      and (name || ' | ' || message) !~ '[0-9]([[:space:]()-]*[0-9]){10,}')
));

-- 3. Slow down anyone sending too much at once
create or replace function public.bloom_rate_limit() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.kind = 'reset' then return new; end if;                -- the host's reset is never slowed down
  if (select count(*) from public.bloom_events where client = new.client and created_at > now() - interval '20 seconds') >= 8 then
    raise exception 'Too many in a short time. Please wait a moment.';
  end if;
  if new.kind = 'wish' and (select count(*) from public.bloom_events where client = new.client and kind = 'wish' and created_at > now() - interval '10 minutes') >= 3 then
    raise exception 'Too many wishes at once. Please wait a little.';
  end if;
  -- limits a made-up browser id can't get around: per invitation, and for the whole guestbook
  if (select count(*) from public.bloom_events where invite = new.invite and created_at > now() - interval '1 minute') >= 90 then
    raise exception 'Too many in a short time. Please wait a moment.';
  end if;
  if (select count(*) from public.bloom_events where invite = new.invite) >= 10000 then
    raise exception 'This guestbook is full.';             -- the host's reset empties it again
  end if;
  return new;
end $$;
drop trigger if exists bloom_rate_limit on public.bloom_events;
create trigger bloom_rate_limit before insert on public.bloom_events for each row execute function public.bloom_rate_limit();

-- 3b. Which kinds are allowed (kept separate so older setups get updated when this runs again)
alter table public.bloom_events drop constraint if exists bloom_events_kind_check;
alter table public.bloom_events add constraint bloom_events_kind_check check (kind in ('gift', 'cheer', 'wish', 'reset'));

-- 3c. Wishes can be up to 1000 characters
alter table public.bloom_events drop constraint if exists bloom_events_message_check;
alter table public.bloom_events add constraint bloom_events_message_check check (char_length(message) <= 1000);

-- 4. Send new rows to everyone who has the invitation open
do $$ begin
  alter publication supabase_realtime add table public.bloom_events;
exception when duplicate_object then null;
end $$;

-- 5. Let the page read and add (needed if 'grant API access automatically' was off)
grant select, insert on public.bloom_events to anon, authenticated;

-- 6. The host's "clear the garden" button
--    The code is stored only as a scrambled hash, in a table guests can't read.
create extension if not exists pgcrypto with schema extensions;
create table if not exists public.bloom_owner (
  id         int primary key default 1 check (id = 1),
  code_hash  text not null
);
alter table public.bloom_owner enable row level security;      -- no policies, so guests can't read it
revoke all on public.bloom_owner from anon, authenticated;

-- wrong guesses are counted; after 8 in 15 minutes the reset stops checking codes for a while
-- (if someone locks you out on purpose, run:  delete from public.bloom_attempts;  to unlock it)
create table if not exists public.bloom_attempts (at timestamptz not null default now());
alter table public.bloom_attempts enable row level security;
revoke all on public.bloom_attempts from anon, authenticated;

-- returns how many rows were removed, or -1 for a wrong code, -2 while locked after too many wrong codes
drop function if exists public.bloom_reset(text, text, boolean);
create or replace function public.bloom_reset(p_invite text, p_code text, p_wishes boolean default false)
returns integer language plpgsql security definer set search_path = public, extensions as $$
declare h text; n integer;
begin
  delete from public.bloom_attempts where at < now() - interval '1 day';
  if (select count(*) from public.bloom_attempts where at > now() - interval '15 minutes') >= 8 then
    return -2;
  end if;
  select code_hash into h from public.bloom_owner where id = 1;
  if h is null or coalesce(p_code, '') = '' or crypt(p_code, h) <> h then
    insert into public.bloom_attempts default values;
    return -1;
  end if;
  delete from public.bloom_events
   where invite = p_invite and (kind in ('gift', 'cheer', 'reset') or (p_wishes and kind = 'wish'));
  get diagnostics n = row_count;
  insert into public.bloom_events (invite, kind, item, client)  -- tells open pages to clear too
  values (p_invite, 'reset', case when p_wishes then 'all' else 'gifts' end, 'host');
  return n;
end $$;
revoke all on function public.bloom_reset(text, text, boolean) from public;
grant execute on function public.bloom_reset(text, text, boolean) to anon, authenticated;

-- 7. Set your host code: put your own phrase between the quotes, select ONLY these lines and click Run.
--    Run it again any time to change the code.
-- insert into public.bloom_owner (id, code_hash) values (1, extensions.crypt('your secret phrase here', extensions.gen_salt('bf', 10)))
-- on conflict (id) do update set code_hash = excluded.code_hash;
