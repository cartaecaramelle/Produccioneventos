-- =====================================================================
-- PRODUCCIÓN DE EVENTOS · Esquema Supabase + RLS
-- Pegar completo en: Supabase > SQL Editor > New query > Run
--
-- ANTES: Authentication > Users > Add user (marca "Auto Confirm User")
--   admin@produccion.local  + contraseña
--   cocina@produccion.local + contraseña
-- Y en Authentication > Providers > Email: desactiva "Allow new users
-- to sign up" para que nadie más pueda registrarse.
-- =====================================================================

-- Rol según el correo dummy del JWT (solo existen dos usuarios)
create or replace function public.app_rol() returns text
language sql stable as $$
  select case auth.jwt()->>'email'
    when 'admin@produccion.local' then 'admin'
    when 'cocina@produccion.local' then 'cocina'
  end
$$;

-- ---------- EVENTOS ----------
create table if not exists public.eventos (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null,
  fecha      date not null,
  pax        integer not null default 0,
  menu       text,                          -- ej: "Finger Opción II", "Vino Español Clásico"
  notas      text,
  archivos   jsonb not null default '[]',   -- metadatos de archivos pesados (viven en S3/B2)
  created_at timestamptz not null default now()
);

-- ---------- RECETAS (hojas "Recetas de Finger") ----------
create table if not exists public.recetas (
  id           uuid primary key default gen_random_uuid(),
  nombre       text not null,
  categoria    text default 'Otra',
  area         text default 'Coffee break / Catering',
  rendimiento_g numeric,
  porciones    numeric,
  ingredientes jsonb not null default '[]', -- [{"n":"Mayonesa","g":300}]
  instrucciones text,
  created_at   timestamptz not null default now()
);

-- ---------- HOJAS DE PRODUCCIÓN (hojas "HP_...") ----------
create table if not exists public.hojas_produccion (
  id         uuid primary key default gen_random_uuid(),
  evento_id  uuid not null references public.eventos(id) on delete cascade,
  receta_id  uuid references public.recetas(id) on delete set null,
  plato      text not null,
  orden      integer not null default 0,
  items      jsonb not null default '[]',   -- [{"n":"Pollo","g":40,"u":null}] por PAX (GRS / UND)
  notas      text,
  estado     text not null default 'Pendiente'
             check (estado in ('Pendiente','En Cocina','Listo para Enviar')),
  updated_at timestamptz not null default now()
);
create index if not exists hp_evento_idx on public.hojas_produccion(evento_id);

-- ---------- RLS ----------
alter table public.eventos           enable row level security;
alter table public.recetas           enable row level security;
alter table public.hojas_produccion  enable row level security;

do $$
declare t text;
begin
  foreach t in array array['eventos','recetas','hojas_produccion'] loop
    execute format('drop policy if exists "lectura" on public.%I', t);
    execute format('drop policy if exists "admin_total" on public.%I', t);
    -- admin y cocina pueden leer
    execute format('create policy "lectura" on public.%I for select to authenticated using (public.app_rol() is not null)', t);
    -- solo admin crea / edita / borra
    execute format('create policy "admin_total" on public.%I for all to authenticated using (public.app_rol()=''admin'') with check (public.app_rol()=''admin'')', t);
  end loop;
end $$;

-- cocina puede ACTUALIZAR hojas de producción (limitado a "estado" por el trigger)
drop policy if exists "cocina_estado" on public.hojas_produccion;
create policy "cocina_estado" on public.hojas_produccion
  for update to authenticated
  using (public.app_rol()='cocina') with check (public.app_rol()='cocina');

-- RLS no filtra columnas: este trigger impide que cocina cambie algo que no sea el estado
create or replace function public.hp_solo_estado() returns trigger
language plpgsql as $$
begin
  if public.app_rol()='cocina' then
    if (to_jsonb(new) - 'estado' - 'updated_at') is distinct from (to_jsonb(old) - 'estado' - 'updated_at') then
      raise exception 'El usuario cocina solo puede cambiar el estado';
    end if;
  end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists hp_solo_estado on public.hojas_produccion;
create trigger hp_solo_estado before update on public.hojas_produccion
  for each row execute function public.hp_solo_estado();

-- Realtime opcional (la cocina ve los cambios de estado al instante)
-- alter publication supabase_realtime add table public.hojas_produccion;
