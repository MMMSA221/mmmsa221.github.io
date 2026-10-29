-- ═══════════════════════════════════════════════════════════════════════════
-- 010_grupos.sql · Acceso por grupos al Hall de Herramientas · Grupo ECIPSA
-- Supabase de Herramientas (xwprtfxtrwcyrzdiamvd) → SQL Editor.
--
-- Idea: cada persona pertenece a uno o más GRUPOS; cada grupo habilita
-- HERRAMIENTAS. Al cambiar un grupo o sus miembros, un trigger recalcula
-- las herramientas de la persona en public.accesos (de donde las toma el
-- trigger accesos_al_crear_usuario al crear un usuario) y en el
-- app_metadata del usuario (lo que leen el hall y ECI.exigir).
-- public.accesos sigue guardando nombre, rol y activo como siempre.
--
-- Todo vive en el esquema "admin", que la API de Supabase NO expone:
-- solo se administra desde el SQL Editor (o el Table Editor).
-- Se puede correr dos veces sin romper nada.
-- ═══════════════════════════════════════════════════════════════════════════


-- ── 0. DIAGNÓSTICO (solo lectura) · correr primero y revisar ────────────────
-- Quién tiene qué hoy
select email,
       raw_app_meta_data->>'nombre'      as nombre,
       raw_app_meta_data->>'rol'         as rol,
       raw_app_meta_data->'herramientas' as herramientas
from auth.users order by email;

-- ¿Existe la tabla vieja public.accesos y algún trigger que escriba app_metadata?
select column_name, data_type from information_schema.columns
where table_schema = 'public' and table_name = 'accesos' order by ordinal_position;

select tgname as trigger, tgrelid::regclass as tabla
from pg_trigger
where not tgisinternal and tgrelid::regclass::text in ('public.accesos', 'auth.users');


-- ── 1. ESTRUCTURA ───────────────────────────────────────────────────────────
create schema if not exists admin;
revoke all on schema admin from public, anon, authenticated;

create table if not exists admin.herramientas (
  codigo text primary key,              -- el que usa ECI.exigir('<codigo>')
  nombre text not null
);

create table if not exists admin.grupos (
  codigo      text primary key,
  nombre      text not null,
  descripcion text
);

create table if not exists admin.grupo_herramientas (
  grupo       text references admin.grupos(codigo)       on update cascade on delete cascade,
  herramienta text references admin.herramientas(codigo) on update cascade on delete cascade,
  primary key (grupo, herramienta)
);

create table if not exists admin.grupo_miembros (
  grupo text references admin.grupos(codigo) on update cascade on delete cascade,
  email text not null check (email = lower(trim(email))),
  primary key (grupo, email)
);


-- ── 2. RECÁLCULO DE PERMISOS ────────────────────────────────────────────────
-- Escribe en el usuario: herramientas = unión de las de sus grupos; grupos = sus grupos.
-- Solo toca a quien se le pasa; nadie pierde accesos por correr este script.
create or replace function admin.aplicar_accesos(p_email text)
returns text[] language plpgsql security definer set search_path = admin, public, auth, pg_temp as $$
declare
  v_mail  text := lower(trim(p_email));
  v_herr  text[];
  v_grup  text[];
begin
  select coalesce(array_agg(distinct gh.herramienta order by gh.herramienta), '{}')
    into v_herr
    from admin.grupo_miembros m join admin.grupo_herramientas gh on gh.grupo = m.grupo
   where m.email = v_mail;

  select coalesce(array_agg(m.grupo order by m.grupo), '{}')
    into v_grup
    from admin.grupo_miembros m where m.email = v_mail;

  -- 1) public.accesos: la usa el trigger accesos_al_crear_usuario al crear el usuario.
  --    Se mantiene al día para que no haya dos versiones de los permisos.
  update public.accesos set herramientas = v_herr where lower(email) = v_mail;
  if not found and array_length(v_grup, 1) > 0 then
    begin
      insert into public.accesos (email, herramientas, activo) values (v_mail, v_herr, true);
    exception when others then
      raise notice 'No se pudo crear la fila de % en public.accesos (%). Cargala a mano con su nombre.', v_mail, sqlerrm;
    end;
  end if;

  -- 2) El usuario (si ya existe): es lo que leen el hall y ECI.exigir.
  update auth.users
     set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
                             || jsonb_build_object('herramientas', to_jsonb(v_herr),
                                                   'grupos',       to_jsonb(v_grup)),
         updated_at = now()
   where lower(email) = v_mail;

  return v_herr;
end $$;

-- Recalcula a todos los que están en algún grupo
create or replace function admin.aplicar_todos()
returns integer language plpgsql security definer set search_path = admin, public, auth, pg_temp as $$
declare r record; n integer := 0;
begin
  for r in select distinct email from admin.grupo_miembros loop
    perform admin.aplicar_accesos(r.email); n := n + 1;
  end loop;
  return n;
end $$;

-- Trigger: alta / baja / cambio de miembro
create or replace function admin.tg_miembros()
returns trigger language plpgsql security definer set search_path = admin, public, auth, pg_temp as $$
begin
  if tg_op in ('INSERT', 'UPDATE') then perform admin.aplicar_accesos(new.email); end if;
  if tg_op in ('DELETE', 'UPDATE') then perform admin.aplicar_accesos(old.email); end if;
  return null;
end $$;

drop trigger if exists aplicar_miembros on admin.grupo_miembros;
create trigger aplicar_miembros after insert or update or delete on admin.grupo_miembros
  for each row execute function admin.tg_miembros();

-- Trigger: se agrega o quita una herramienta a un grupo → recalcula a sus miembros
create or replace function admin.tg_grupo_herramientas()
returns trigger language plpgsql security definer set search_path = admin, public, auth, pg_temp as $$
declare r record;
begin
  for r in select distinct email from admin.grupo_miembros
            where grupo in (case when tg_op <> 'DELETE' then new.grupo end,
                            case when tg_op <> 'INSERT' then old.grupo end) loop
    perform admin.aplicar_accesos(r.email);
  end loop;
  return null;
end $$;

drop trigger if exists aplicar_grupo_herramientas on admin.grupo_herramientas;
create trigger aplicar_grupo_herramientas after insert or update or delete on admin.grupo_herramientas
  for each row execute function admin.tg_grupo_herramientas();

-- Nadie desde la web puede ejecutar estas funciones
revoke all on all functions in schema admin from public, anon, authenticated;
revoke all on all tables    in schema admin from public, anon, authenticated;

-- Vista para revisar quién ve qué
create or replace view admin.v_accesos as
select u.email,
       u.raw_app_meta_data->>'nombre' as nombre,
       u.raw_app_meta_data->>'rol'    as rol,
       u.raw_app_meta_data->'grupos'       as grupos,
       u.raw_app_meta_data->'herramientas' as herramientas,
       u.last_sign_in_at
from auth.users u order by u.email;
revoke all on admin.v_accesos from public, anon, authenticated;


-- ── 3. CATÁLOGO DE HERRAMIENTAS (una fila por tarjeta del hall) ─────────────
insert into admin.herramientas (codigo, nombre) values
  ('cabida',       'Análisis de Cabida'),
  ('simulador',    'Simulación de Plan de Inversión'),
  ('licitaciones', 'Licitaciones'),
  ('loteos',       'Tablero de Loteos Natania 360')
on conflict (codigo) do update set nombre = excluded.nombre;


-- ── 4. GRUPOS (definidos el 29/10/2026) ────────────────────────────────────
insert into admin.grupos (codigo, nombre, descripcion) values
  ('produccion', 'Área Producción', 'Proyecto, gestiones, obra, planificación y costos: todas las herramientas'),
  ('comercial',  'Área Comercial',  'Administración, comercial, Natania Directa, pre entrega: solo Loteos'),
  ('proyeccion', 'Área Proyección', 'Solo el Simulador del plan de inversión')
on conflict (codigo) do update set nombre = excluded.nombre, descripcion = excluded.descripcion;

insert into admin.grupo_herramientas (grupo, herramienta) values
  ('produccion', 'cabida'), ('produccion', 'simulador'), ('produccion', 'licitaciones'), ('produccion', 'loteos'),
  ('comercial',  'loteos'),
  ('proyeccion', 'simulador')
on conflict do nothing;

-- Grupos de prueba de una versión anterior de este script, si quedaron sin miembros
delete from admin.grupos g
 where g.codigo in ('todas', 'planeamiento', 'finanzas', 'abastecimiento', 'loteos')
   and not exists (select 1 from admin.grupo_miembros m where m.grupo = g.codigo);


-- ── 5. TRANSICIÓN: nadie pierde Loteos ──────────────────────────────────────
-- Hasta hoy la tarjeta de Loteos la veía todo usuario logueado. Desde ahora
-- exige el código 'loteos'. Se lo agrega a quien ya está dado de alta, para
-- que nada cambie hasta que se le asigne un grupo (ahí se recalcula todo).
update public.accesos
   set herramientas = array_append(coalesce(herramientas, '{}'), 'loteos')
 where not ('loteos' = any(coalesce(herramientas, '{}')))
   and not exists (select 1 from admin.grupo_miembros m where m.email = lower(public.accesos.email));

update auth.users
   set raw_app_meta_data = jsonb_set(coalesce(raw_app_meta_data, '{}'::jsonb), '{herramientas}',
                                     coalesce(raw_app_meta_data->'herramientas', '[]'::jsonb) || '["loteos"]'::jsonb),
       updated_at = now()
 where not coalesce(raw_app_meta_data->'herramientas', '[]'::jsonb) ? 'loteos'
   and not exists (select 1 from admin.grupo_miembros m where m.email = lower(auth.users.email));


-- ── 6. ASIGNAR PERSONAS (ejemplos; reemplazar los mails) ────────────────────
-- insert into admin.grupo_miembros (grupo, email) values
--   ('produccion', 'persona1@construirsa.com'),
--   ('comercial',  'persona2@construirsa.com'),
--   ('proyeccion', 'persona2@construirsa.com')
-- on conflict do nothing;
--
-- Sacar a alguien de un grupo:
-- delete from admin.grupo_miembros where grupo = 'proyeccion' and email = 'persona@construirsa.com';
--
-- Revisar el resultado:
-- select * from admin.v_accesos;
--
-- La persona ve el cambio al volver a ingresar (o en menos de 1 hora, cuando se renueva la sesión).
