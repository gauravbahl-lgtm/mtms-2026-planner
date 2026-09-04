create extension if not exists pgcrypto with schema extensions;

create table if not exists public.conference_planner_schedules (
  conference_id text not null,
  pin_hash text not null,
  picked jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (conference_id, pin_hash),
  constraint conference_id_format check (conference_id ~ '^[a-z0-9][a-z0-9-]{1,63}$')
);

alter table public.conference_planner_schedules enable row level security;
revoke all on table public.conference_planner_schedules from anon, authenticated;

create or replace function public.get_conference_schedule(conference_id text, planner_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare result jsonb;
begin
  if conference_id !~ '^[a-z0-9][a-z0-9-]{1,63}$' then
    raise exception 'Invalid conference identifier';
  end if;
  if planner_pin !~ '^[0-9]{4,6}$' then
    raise exception 'PIN must contain four to six digits';
  end if;
  select picked into result
  from public.conference_planner_schedules
  where conference_planner_schedules.conference_id = get_conference_schedule.conference_id
    and pin_hash = encode(digest('conf-planner-v1:' || get_conference_schedule.conference_id || ':' || planner_pin, 'sha256'), 'hex');

  -- Transparently retain PIN schedules made by the original MTMS-only app.
  if result is null and get_conference_schedule.conference_id = 'mtms-2026'
     and to_regclass('public.planner_schedules') is not null then
    -- Dynamic SQL keeps this function installable on a brand-new project where
    -- the legacy table has never existed.
    execute
      'select picked from public.planner_schedules where pin_hash = $1'
      into result
      using encode(digest('mtms26:' || planner_pin, 'sha256'), 'hex');
    if result is not null then
      insert into public.conference_planner_schedules(conference_id, pin_hash, picked)
      values (
        get_conference_schedule.conference_id,
        encode(digest('conf-planner-v1:' || get_conference_schedule.conference_id || ':' || planner_pin, 'sha256'), 'hex'),
        result
      ) on conflict (conference_id, pin_hash) do nothing;
    end if;
  end if;
  return coalesce(result, '[]'::jsonb);
end;
$$;

create or replace function public.update_conference_talk(
  conference_id text,
  planner_pin text,
  talk_id text,
  should_add boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  key text;
  result jsonb;
begin
  if conference_id !~ '^[a-z0-9][a-z0-9-]{1,63}$' then
    raise exception 'Invalid conference identifier';
  end if;
  if planner_pin !~ '^[0-9]{4,6}$' then
    raise exception 'PIN must contain four to six digits';
  end if;
  if talk_id !~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,199}$' then
    raise exception 'Invalid talk identifier';
  end if;

  key := encode(digest('conf-planner-v1:' || update_conference_talk.conference_id || ':' || planner_pin, 'sha256'), 'hex');
  insert into public.conference_planner_schedules(conference_id, pin_hash, picked)
  values (update_conference_talk.conference_id, key, '[]'::jsonb)
  on conflict (conference_id, pin_hash) do nothing;

  if should_add then
    update public.conference_planner_schedules
    set picked = case when picked ? talk_id then picked else picked || to_jsonb(talk_id) end,
        updated_at = now()
    where conference_planner_schedules.conference_id = update_conference_talk.conference_id
      and pin_hash = key;
  else
    update public.conference_planner_schedules
    set picked = picked - talk_id,
        updated_at = now()
    where conference_planner_schedules.conference_id = update_conference_talk.conference_id
      and pin_hash = key;
  end if;

  select picked into result
  from public.conference_planner_schedules
  where conference_planner_schedules.conference_id = update_conference_talk.conference_id
    and pin_hash = key;
  return result;
end;
$$;

revoke all on function public.get_conference_schedule(text, text) from public;
revoke all on function public.update_conference_talk(text, text, text, boolean) from public;
grant execute on function public.get_conference_schedule(text, text) to anon, authenticated;
grant execute on function public.update_conference_talk(text, text, text, boolean) to anon, authenticated;
notify pgrst, 'reload schema';
