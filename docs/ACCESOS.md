# Accesos por grupos

Cada persona tiene **un solo usuario** (mail y contraseña) para todas las herramientas. Lo que ve depende de sus **grupos**:

```
persona ──▶ grupos ──▶ herramientas
```

- El hall muestra solo las tarjetas de las herramientas habilitadas.
- Cada herramienta llama a `ECI.exigir('<código>')`: si alguien entra por el link directo sin permiso, vuelve al hall con un aviso.
- Una persona en varios grupos ve la suma de todos.

Todo se administra en Supabase (proyecto de Herramientas) → **SQL Editor**. Las tablas viven en el esquema `admin`, que la web no puede leer.

## Puesta en marcha (una sola vez)

1. Correr la sección **0 (Diagnóstico)** de `sql/010_grupos.sql` y revisar quién tiene qué hoy.
2. Correr el archivo completo. No le saca acceso a nadie: a todos los usuarios actuales les agrega `loteos`, que hasta ahora veía todo el mundo.
3. Asignar a cada persona a sus grupos (ver abajo). En ese momento sus permisos pasan a salir solo de los grupos.

## Tareas habituales

**Ver quién ve qué**
```sql
select * from admin.v_accesos;
```

**Poner a una persona en un grupo**
```sql
insert into admin.grupo_miembros (grupo, email) values ('planeamiento', 'persona@construirsa.com')
on conflict do nothing;
```

**Sacarla de un grupo**
```sql
delete from admin.grupo_miembros where grupo = 'planeamiento' and email = 'persona@construirsa.com';
```

**Crear un grupo y darle herramientas**
```sql
insert into admin.grupos (codigo, nombre) values ('obras', 'Obras');
insert into admin.grupo_herramientas (grupo, herramienta) values ('obras', 'simulador'), ('obras', 'licitaciones');
```
Si el grupo ya tiene miembros, se actualizan solos.

**Ver los grupos y sus herramientas**
```sql
select g.codigo, g.nombre, array_agg(gh.herramienta order by gh.herramienta) as herramientas
from admin.grupos g left join admin.grupo_herramientas gh on gh.grupo = g.codigo
group by g.codigo, g.nombre order by g.codigo;
```

La persona ve el cambio al volver a ingresar, o sola en menos de una hora.

**Usuario nuevo:** primero se crea en Supabase → Authentication → Users → "Add user" (con mail y contraseña inicial, marcando "Auto confirm"). Después se lo pone en sus grupos. El nombre que muestra el hall se carga en `app_metadata.nombre`:
```sql
update auth.users set raw_app_meta_data = raw_app_meta_data || '{"nombre":"Nombre Apellido"}'
where email = 'persona@construirsa.com';
```

## Sumar una herramienta nueva

1. Elegir un código corto (ej.: `obras`).
2. En la página de la herramienta, dentro del `<head>`:
   ```html
   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.js"></script>
   <script src="/sesion.js"></script>
   <script>ECI.exigir('obras');</script>
   ```
3. En `index.html` del hall, sumar la tarjeta a `HERRAMIENTAS` con `herr: 'obras'` y una letra libre (el plano dibuja A a D; para más lotes hay que ampliar el SVG).
4. En Supabase: `insert into admin.herramientas values ('obras', 'Nombre visible');` y agregarla a los grupos que correspondan.

## Límites a tener en cuenta

- `ECI.exigir` oculta la pantalla, pero **no protege los archivos** del repo: si los datos están dentro del repo (como `licitaciones/datos.js`), cualquiera con el link directo al archivo los puede bajar. Los datos sensibles tienen que vivir en Supabase con RLS.
- El Tablero de Loteos tiene su propio login y otro Supabase: el grupo `loteos` solo decide si la tarjeta aparece en el hall.
- La tabla vieja `public.accesos` (si existe) queda en desuso: los permisos se manejan desde los grupos.
