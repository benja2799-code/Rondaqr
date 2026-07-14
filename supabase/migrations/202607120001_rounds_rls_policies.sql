-- RondaQR v2.0
-- Políticas RLS seguras para la tabla public.rounds.
-- Esta migración es idempotente: no duplica políticas si ya existen.

alter table public.rounds enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'rounds'
      and policyname = 'rounds_select_same_installation_or_own'
  ) then
    create policy "rounds_select_same_installation_or_own"
      on public.rounds
      for select
      to authenticated
      using (
        guard_id = auth.uid()
        or installation_id in (
          select profiles.installation_id
          from public.profiles
          where profiles.id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'rounds'
      and policyname = 'rounds_insert_own_guard'
  ) then
    create policy "rounds_insert_own_guard"
      on public.rounds
      for insert
      to authenticated
      with check (
        guard_id = auth.uid()
        and installation_id in (
          select profiles.installation_id
          from public.profiles
          where profiles.id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'rounds'
      and policyname = 'rounds_update_own_guard'
  ) then
    create policy "rounds_update_own_guard"
      on public.rounds
      for update
      to authenticated
      using (guard_id = auth.uid())
      with check (guard_id = auth.uid());
  end if;
end $$;
