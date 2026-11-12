-- CURRENT coordinated update. Run ONCE on the existing Supabase project.
-- Back up your database before running. DO NOT rerun schema.sql or migration_parent_accounts.sql.
begin;

alter table public.training_targets add column if not exists block_title text;
create index if not exists training_targets_lookup_idx on public.training_targets(athlete_id,start_date desc);

-- An athlete can have a scheduled week; coaches can cancel future weeks.
drop policy if exists targets_delete on public.training_targets;
create policy targets_delete on public.training_targets for delete to authenticated
using (coach_id=auth.uid() and exists(select 1 from public.coach_athletes ca where ca.coach_id=auth.uid() and ca.athlete_id=training_targets.athlete_id) and start_date>current_date);

-- A coach can correct assigned athletes' session records. The existing revision trigger
-- (if installed) keeps a copy of the previous row. Parents retain read-only access.
drop policy if exists logs_coach_update on public.training_sessions;
create policy logs_coach_update on public.training_sessions for update to authenticated
using (exists(select 1 from public.coach_athletes ca where ca.coach_id=auth.uid() and ca.athlete_id=training_sessions.athlete_id))
with check (exists(select 1 from public.coach_athletes ca where ca.coach_id=auth.uid() and ca.athlete_id=training_sessions.athlete_id));
grant update on public.training_sessions to authenticated;

-- Private coach-managed training library. Files are stored in a PRIVATE bucket.
create table if not exists public.training_library(
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.profiles(id),
  title text not null check(length(title) between 1 and 160),
  category text not null,
  duration_minutes integer not null check(duration_minutes between 1 and 600),
  file_path text not null unique,
  created_at timestamptz not null default now()
);
alter table public.training_library enable row level security;
drop policy if exists library_read on public.training_library;
create policy library_read on public.training_library for select to authenticated using (true);
drop policy if exists library_insert on public.training_library;
create policy library_insert on public.training_library for insert to authenticated
with check (coach_id=auth.uid() and public.is_coach() and split_part(file_path,'/',1)=auth.uid()::text);
drop policy if exists library_delete on public.training_library;
create policy library_delete on public.training_library for delete to authenticated
using (coach_id=auth.uid() and public.is_coach());
grant select,insert,delete on public.training_library to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('training-library','training-library',false,10485760,array['application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict (id) do update set public=false,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists current_library_read on storage.objects;
create policy current_library_read on storage.objects for select to authenticated using (bucket_id='training-library');
drop policy if exists current_library_upload on storage.objects;
create policy current_library_upload on storage.objects for insert to authenticated
with check(bucket_id='training-library' and public.is_coach() and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists current_library_remove on storage.objects;
create policy current_library_remove on storage.objects for delete to authenticated
using(bucket_id='training-library' and public.is_coach() and (storage.foldername(name))[1]=auth.uid()::text);

-- Limit coach access to athletes they are actually assigned, not all athletes.
create or replace function public.current_assigned_coach(child_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.coach_athletes ca join public.profiles p on p.id=ca.coach_id and p.role='coach'
 where ca.coach_id=(select auth.uid()) and ca.athlete_id=child_id);
$$;
revoke all on function public.current_assigned_coach(uuid) from public,anon;
grant execute on function public.current_assigned_coach(uuid) to authenticated;

drop policy if exists parent_links_read on public.parent_athletes;
create policy parent_links_read on public.parent_athletes for select to authenticated
using(parent_id=auth.uid() or public.current_assigned_coach(athlete_id));
grant select on public.parent_athletes to authenticated;

drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated
using(id=auth.uid() or public.current_assigned_coach(id) or public.is_linked_parent(id));
drop policy if exists logs_read on public.training_sessions;
create policy logs_read on public.training_sessions for select to authenticated
using(athlete_id=auth.uid() or public.current_assigned_coach(athlete_id) or public.is_linked_parent(athlete_id));
drop policy if exists targets_read on public.training_targets;
create policy targets_read on public.training_targets for select to authenticated
using(athlete_id=auth.uid() or public.current_assigned_coach(athlete_id) or public.is_linked_parent(athlete_id));
drop policy if exists perms_read on public.exercise_permissions;
create policy perms_read on public.exercise_permissions for select to authenticated
using(athlete_id=auth.uid() or public.current_assigned_coach(athlete_id) or public.is_linked_parent(athlete_id));
drop policy if exists plans_read on public.session_plans;
create policy plans_read on public.session_plans for select to authenticated
using(athlete_id=auth.uid() or public.current_assigned_coach(athlete_id) or public.is_linked_parent(athlete_id));
-- If your existing project has the original permissive coach policies, narrow
-- their write access to assigned athletes as well. Safe to run after migration.
drop policy if exists targets_insert on public.training_targets;
create policy targets_insert on public.training_targets for insert to authenticated
with check(coach_id=auth.uid() and public.current_assigned_coach(athlete_id));
drop policy if exists targets_update on public.training_targets;
create policy targets_update on public.training_targets for update to authenticated
using(coach_id=auth.uid() and public.current_assigned_coach(athlete_id))
with check(coach_id=auth.uid() and public.current_assigned_coach(athlete_id));
drop policy if exists perms_insert on public.exercise_permissions;
create policy perms_insert on public.exercise_permissions for insert to authenticated
with check(coach_id=auth.uid() and public.current_assigned_coach(athlete_id));
drop policy if exists perms_update on public.exercise_permissions;
create policy perms_update on public.exercise_permissions for update to authenticated
using(coach_id=auth.uid() and public.current_assigned_coach(athlete_id))
with check(coach_id=auth.uid() and public.current_assigned_coach(athlete_id));

commit;
