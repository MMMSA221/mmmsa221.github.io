-- Herramienta "Entregas de viviendas Natania" (/entregas/)
-- Correr una vez en Supabase (proyecto de Herramientas) → SQL Editor, después de 010_grupos.sql.
-- La ven los grupos produccion y comercial. Los miembros de esos grupos se actualizan solos.

insert into admin.herramientas (codigo, nombre) values
  ('entregas', 'Entregas de viviendas Natania')
on conflict (codigo) do update set nombre = excluded.nombre;

insert into admin.grupo_herramientas (grupo, herramienta) values
  ('produccion', 'entregas'),
  ('comercial',  'entregas')
on conflict do nothing;

-- Control: quién la ve ahora
-- select email, nombre from admin.v_accesos where herramientas ? 'entregas';
