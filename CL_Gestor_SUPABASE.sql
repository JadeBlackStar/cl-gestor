-- CL Gestor 1.1: almacenamiento aislado por usuario autenticado
-- Ejecutar en Supabase > SQL Editor.

create table if not exists public.cl_gestor_datos (
  usuario_id uuid primary key references auth.users(id) on delete cascade,
  datos jsonb not null default '{}'::jsonb,
  actualizado_en timestamptz not null default now()
);

alter table public.cl_gestor_datos enable row level security;
alter table public.cl_gestor_datos force row level security;

-- Privilegios explícitos: solo usuarios autenticados pueden operar en la tabla.
revoke all on table public.cl_gestor_datos from anon;
revoke all on table public.cl_gestor_datos from public;
grant select, insert, update, delete on table public.cl_gestor_datos to authenticated;

drop policy if exists "Cada usuario accede a sus propios datos" on public.cl_gestor_datos;
create policy "Cada usuario accede a sus propios datos"
on public.cl_gestor_datos
for all to authenticated
using (auth.uid() = usuario_id)
with check (auth.uid() = usuario_id);

-- Habilita Realtime sin error si la tabla ya estaba añadida a la publicación.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'cl_gestor_datos'
  ) then
    alter publication supabase_realtime add table public.cl_gestor_datos;
  end if;
end $$;
