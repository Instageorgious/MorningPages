-- Morning Pages: Supabase Schema
-- Run this entire file in Supabase → SQL Editor → New Query

-- 1. ENTRIES TABLE
create table if not exists public.entries (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  date          date not null,
  text          text not null default '',
  peak_words    integer not null default 0,
  completed_pages integer not null default 0,
  pages_carried integer not null default 0,
  is_owl        boolean not null default false,
  completed_at  timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique(user_id, date)
);

-- 2. USER SETTINGS TABLE (streak data, dayStartTime, milestones, etc.)
create table if not exists public.user_settings (
  user_id             uuid primary key references auth.users(id) on delete cascade,
  day_start_time      text not null default '00:00',
  lifetime_words      integer not null default 0,
  milestones_hit      text[] not null default '{}',
  streak_milestones_hit text[] not null default '{}',
  streak_repair_mode  boolean not null default false,
  streak_prev_length  integer not null default 0,
  streak_missed_days  text[] not null default '{}',
  streak_repaired_days text[] not null default '{}',
  streak_double_days  integer not null default 0,
  streak_bonus_days   integer not null default 0,
  streak_window_expires text,
  updated_at          timestamptz not null default now()
);

-- 3. ROW LEVEL SECURITY
alter table public.entries enable row level security;
alter table public.user_settings enable row level security;

-- Entries: users can only see/edit their own rows
create policy "Users can read own entries"
  on public.entries for select
  using (auth.uid() = user_id);

create policy "Users can insert own entries"
  on public.entries for insert
  with check (auth.uid() = user_id);

create policy "Users can update own entries"
  on public.entries for update
  using (auth.uid() = user_id);

create policy "Users can delete own entries"
  on public.entries for delete
  using (auth.uid() = user_id);

-- Settings: users can only see/edit their own row
create policy "Users can read own settings"
  on public.user_settings for select
  using (auth.uid() = user_id);

create policy "Users can insert own settings"
  on public.user_settings for insert
  with check (auth.uid() = user_id);

create policy "Users can update own settings"
  on public.user_settings for update
  using (auth.uid() = user_id);

-- 4. AUTO-UPDATE updated_at
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger entries_updated_at
  before update on public.entries
  for each row execute function public.set_updated_at();

create trigger settings_updated_at
  before update on public.user_settings
  for each row execute function public.set_updated_at();

-- 5. AUTO-CREATE user_settings row on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.user_settings(user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ── PATCH: run this if you already ran the schema above ──────────────────────
-- Ensures the unique index exists for upsert to work correctly
create unique index if not exists entries_user_date_idx
  on public.entries(user_id, date);

-- Ensure RLS is on (safe to run again)
alter table public.entries enable row level security;
alter table public.user_settings enable row level security;

-- Re-create policies idempotently (drop first if they exist)
drop policy if exists "Users can read own entries" on public.entries;
drop policy if exists "Users can insert own entries" on public.entries;
drop policy if exists "Users can update own entries" on public.entries;
drop policy if exists "Users can delete own entries" on public.entries;
drop policy if exists "Users can read own settings" on public.user_settings;
drop policy if exists "Users can insert own settings" on public.user_settings;
drop policy if exists "Users can update own settings" on public.user_settings;

create policy "Users can read own entries"   on public.entries for select using (auth.uid() = user_id);
create policy "Users can insert own entries" on public.entries for insert with check (auth.uid() = user_id);
create policy "Users can update own entries" on public.entries for update using (auth.uid() = user_id);
create policy "Users can delete own entries" on public.entries for delete using (auth.uid() = user_id);
create policy "Users can read own settings"   on public.user_settings for select using (auth.uid() = user_id);
create policy "Users can insert own settings" on public.user_settings for insert with check (auth.uid() = user_id);
create policy "Users can update own settings" on public.user_settings for update using (auth.uid() = user_id);
