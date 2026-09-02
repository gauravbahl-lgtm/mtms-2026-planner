create extension if not exists pgcrypto;

create table if not exists public.planner_schedules (
  pin_hash text primary key,
  picked jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.planner_schedules enable row level security;
revoke all on table public.planner_schedules from anon, authenticated;

create or replace function public.get_planner_schedule(planner_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare result jsonb;
begin
  if planner_pin !~ '^[0-9]{4}$' then
    raise exception 'PIN must contain exactly four digits';
  end if;
  select picked into result
  from public.planner_schedules
  where pin_hash = encode(digest('mtms26:' || planner_pin, 'sha256'), 'hex');
  return coalesce(result, '[]'::jsonb);
end;
$$;

create or replace function public.update_planner_talk(
  planner_pin text,
  talk_id text,
  should_add boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  key text;
  result jsonb;
begin
  if planner_pin !~ '^[0-9]{4}$' then
    raise exception 'PIN must contain exactly four digits';
  end if;
  if talk_id !~ '^2026-09-0[23]-[a-z0-9-]+$' then
    raise exception 'Invalid talk identifier';
  end if;

  key := encode(digest('mtms26:' || planner_pin, 'sha256'), 'hex');
  insert into public.planner_schedules(pin_hash, picked)
  values (key, '[]'::jsonb)
  on conflict (pin_hash) do nothing;

  if should_add then
    update public.planner_schedules
    set picked = case when picked ? talk_id then picked else picked || to_jsonb(talk_id) end,
        updated_at = now()
    where pin_hash = key;
  else
    update public.planner_schedules
    set picked = picked - talk_id,
        updated_at = now()
    where pin_hash = key;
  end if;

  select picked into result from public.planner_schedules where pin_hash = key;
  return result;
end;
$$;

revoke all on function public.get_planner_schedule(text) from public;
revoke all on function public.update_planner_talk(text, text, boolean) from public;
grant execute on function public.get_planner_schedule(text) to anon, authenticated;
grant execute on function public.update_planner_talk(text, text, boolean) to anon, authenticated;
