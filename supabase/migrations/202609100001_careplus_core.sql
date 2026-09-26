-- CarePlus core schema. Safe to run from the Supabase SQL editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'active')),
  role text check (role in ('patient', 'caregiver')),
  display_name text,
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles add column if not exists status text not null default 'pending';
alter table public.profiles add column if not exists role text;
alter table public.profiles add column if not exists display_name text;
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

create table if not exists public.care_links (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id) on delete cascade,
  caregiver_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'active', 'revoked')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (patient_id, caregiver_id),
  check (patient_id <> caregiver_id)
);

alter table public.care_links add column if not exists id uuid default gen_random_uuid();
alter table public.care_links add column if not exists status text not null default 'pending';
alter table public.care_links add column if not exists created_by uuid references public.profiles(id) on delete set null;
alter table public.care_links add column if not exists created_at timestamptz not null default now();
alter table public.care_links add column if not exists updated_at timestamptz not null default now();
alter table public.care_links alter column status set default 'pending';
create unique index if not exists care_links_id_key on public.care_links(id);
create unique index if not exists care_links_pair_key on public.care_links(patient_id, caregiver_id);

create table if not exists public.patient_details (
  patient_id uuid primary key references public.profiles(id) on delete cascade,
  birth_year integer not null check (birth_year between 1900 and 2100),
  notes text,
  updated_at timestamptz not null default now()
);

create table if not exists public.caregiver_details (
  caregiver_id uuid primary key references public.profiles(id) on delete cascade,
  full_name text not null,
  phone text,
  relationship text,
  updated_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  care_link_id uuid not null references public.care_links(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index if not exists messages_link_created_idx
  on public.messages(care_link_id, created_at);

create table if not exists public.tasks (
  user_id uuid not null references public.profiles(id) on delete cascade,
  item_id uuid not null,
  payload jsonb not null,
  updated_at timestamptz not null,
  created_at timestamptz not null,
  primary key (user_id, item_id)
);
alter table public.tasks add column if not exists payload jsonb;
alter table public.tasks add column if not exists updated_at timestamptz not null default now();
alter table public.tasks add column if not exists created_at timestamptz not null default now();
update public.tasks set payload = '""'::jsonb where payload is null;
create unique index if not exists tasks_user_item_key on public.tasks(user_id, item_id);

create table if not exists public.medicine_inventory (
  user_id uuid not null references public.profiles(id) on delete cascade,
  item_id uuid not null,
  payload jsonb not null,
  updated_at timestamptz not null,
  created_at timestamptz not null,
  primary key (user_id, item_id)
);
alter table public.medicine_inventory add column if not exists payload jsonb;
alter table public.medicine_inventory add column if not exists updated_at timestamptz not null default now();
alter table public.medicine_inventory add column if not exists created_at timestamptz not null default now();
update public.medicine_inventory set payload = '""'::jsonb where payload is null;
create unique index if not exists medicine_inventory_user_item_key
  on public.medicine_inventory(user_id, item_id);

create table if not exists public.diary_entries (
  user_id uuid not null references public.profiles(id) on delete cascade,
  item_id uuid not null,
  payload jsonb not null,
  updated_at timestamptz not null,
  created_at timestamptz not null,
  primary key (user_id, item_id)
);
alter table public.diary_entries add column if not exists payload jsonb;
alter table public.diary_entries add column if not exists updated_at timestamptz not null default now();
alter table public.diary_entries add column if not exists created_at timestamptz not null default now();
update public.diary_entries set payload = '""'::jsonb where payload is null;
create unique index if not exists diary_entries_user_item_key
  on public.diary_entries(user_id, item_id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, status, display_name, email)
  values (
    new.id,
    'pending',
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), ''),
    lower(new.email)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Backfill profiles for accounts that existed before this migration.
insert into public.profiles (id, status, display_name, email)
select
  id,
  'pending',
  nullif(trim(coalesce(raw_user_meta_data ->> 'full_name', '')), ''),
  lower(email)
from auth.users
on conflict (id) do nothing;

create or replace function public.keep_profile_role_immutable()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.role is not null and new.role is distinct from old.role then
    raise exception 'Profile role cannot be changed after setup';
  end if;
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_keep_role_immutable on public.profiles;
create trigger profiles_keep_role_immutable
  before update on public.profiles
  for each row execute procedure public.keep_profile_role_immutable();

create or replace function public.find_care_profile_by_email(p_email text)
returns table (
  id uuid,
  role text,
  status text,
  display_name text,
  email text
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.role, p.status, p.display_name, p.email
  from public.profiles p
  where auth.uid() is not null
    and lower(p.email) = lower(trim(p_email))
  limit 1;
$$;

revoke all on function public.find_care_profile_by_email(text) from public;
grant execute on function public.find_care_profile_by_email(text) to authenticated;

create or replace function public.request_care_link(
  p_patient_id uuid,
  p_caregiver_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_link public.care_links%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if auth.uid() <> p_patient_id and auth.uid() <> p_caregiver_id then
    raise exception 'You must belong to the requested care link';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = p_patient_id and role = 'patient'
  ) then
    raise exception 'Invalid patient account';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = p_caregiver_id and role = 'caregiver'
  ) then
    raise exception 'Invalid caregiver account';
  end if;

  select * into existing_link
  from public.care_links
  where patient_id = p_patient_id and caregiver_id = p_caregiver_id
  for update;

  if not found then
    insert into public.care_links (patient_id, caregiver_id, status, created_by)
    values (p_patient_id, p_caregiver_id, 'pending', auth.uid());
  elsif existing_link.status = 'pending'
    and existing_link.created_by is distinct from auth.uid() then
    update public.care_links
    set status = 'active', updated_at = now()
    where id = existing_link.id;
  elsif existing_link.status = 'revoked' then
    update public.care_links
    set status = 'pending', created_by = auth.uid(), updated_at = now()
    where id = existing_link.id;
  end if;
end;
$$;

revoke all on function public.request_care_link(uuid, uuid) from public;
grant execute on function public.request_care_link(uuid, uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.care_links enable row level security;
alter table public.patient_details enable row level security;
alter table public.caregiver_details enable row level security;
alter table public.messages enable row level security;
alter table public.tasks enable row level security;
alter table public.medicine_inventory enable row level security;
alter table public.diary_entries enable row level security;

drop policy if exists profiles_select_self_or_partner on public.profiles;
create policy profiles_select_self_or_partner on public.profiles
for select to authenticated
using (
  id = auth.uid()
  or exists (
    select 1 from public.care_links link
    where link.status = 'active'
      and (
        (link.patient_id = auth.uid() and link.caregiver_id = profiles.id)
        or (link.caregiver_id = auth.uid() and link.patient_id = profiles.id)
      )
  )
);

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self on public.profiles
for insert to authenticated
with check (id = auth.uid());

drop policy if exists care_links_select_member on public.care_links;
create policy care_links_select_member on public.care_links
for select to authenticated
using (patient_id = auth.uid() or caregiver_id = auth.uid());

drop policy if exists care_links_insert_member on public.care_links;
drop policy if exists care_links_update_member on public.care_links;

drop policy if exists patient_details_member_access on public.patient_details;
create policy patient_details_member_access on public.patient_details
for select to authenticated
using (
  patient_id = auth.uid()
  or exists (
    select 1 from public.care_links link
    where link.patient_id = patient_details.patient_id
      and link.caregiver_id = auth.uid()
      and link.status = 'active'
  )
);
drop policy if exists patient_details_owner_write on public.patient_details;
create policy patient_details_owner_write on public.patient_details
for all to authenticated
using (patient_id = auth.uid())
with check (patient_id = auth.uid());

drop policy if exists caregiver_details_member_access on public.caregiver_details;
create policy caregiver_details_member_access on public.caregiver_details
for select to authenticated
using (
  caregiver_id = auth.uid()
  or exists (
    select 1 from public.care_links link
    where link.caregiver_id = caregiver_details.caregiver_id
      and link.patient_id = auth.uid()
      and link.status = 'active'
  )
);
drop policy if exists caregiver_details_owner_write on public.caregiver_details;
create policy caregiver_details_owner_write on public.caregiver_details
for all to authenticated
using (caregiver_id = auth.uid())
with check (caregiver_id = auth.uid());

drop policy if exists messages_select_member on public.messages;
create policy messages_select_member on public.messages
for select to authenticated
using (
  exists (
    select 1 from public.care_links link
    where link.id = messages.care_link_id
      and link.status = 'active'
      and (link.patient_id = auth.uid() or link.caregiver_id = auth.uid())
  )
);

drop policy if exists messages_insert_member on public.messages;
create policy messages_insert_member on public.messages
for insert to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.care_links link
    where link.id = messages.care_link_id
      and link.status = 'active'
      and (link.patient_id = auth.uid() or link.caregiver_id = auth.uid())
  )
);

drop policy if exists tasks_owner_all on public.tasks;
create policy tasks_owner_all on public.tasks
for all to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.care_links link
    where link.patient_id = tasks.user_id
      and link.caregiver_id = auth.uid()
      and link.status = 'active'
  )
)
with check (
  user_id = auth.uid()
  or exists (
    select 1 from public.care_links link
    where link.patient_id = tasks.user_id
      and link.caregiver_id = auth.uid()
      and link.status = 'active'
  )
);

drop policy if exists diary_owner_all on public.diary_entries;
create policy diary_owner_all on public.diary_entries
for all to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.care_links link
    where link.patient_id = diary_entries.user_id
      and link.caregiver_id = auth.uid()
      and link.status = 'active'
  )
)
with check (
  user_id = auth.uid()
  or exists (
    select 1 from public.care_links link
    where link.patient_id = diary_entries.user_id
      and link.caregiver_id = auth.uid()
      and link.status = 'active'
  )
);

drop policy if exists medicine_inventory_owner_all on public.medicine_inventory;
create policy medicine_inventory_owner_all on public.medicine_inventory
for all to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.care_links link
    where link.patient_id = medicine_inventory.user_id
      and link.caregiver_id = auth.uid()
      and link.status = 'active'
  )
)
with check (
  user_id = auth.uid()
  or exists (
    select 1 from public.care_links link
    where link.patient_id = medicine_inventory.user_id
      and link.caregiver_id = auth.uid()
      and link.status = 'active'
  )
);
