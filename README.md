# Herramientas · Grupo ECIPSA

Hall con ingreso único a las herramientas del equipo. Publicado en **https://mmmsa221.github.io/**

Cada persona entra una sola vez con su mail y ve **solo las herramientas de sus grupos**.

## Mapa de repositorios

Todo se publica con GitHub Pages bajo el mismo dominio, así que todas las páginas comparten la sesión.

| Herramienta | Código de permiso | Repositorio | Dirección publicada |
|---|---|---|---|
| Hall (este repo) | — | [mmmsa221/mmmsa221.github.io](https://github.com/mmmsa221/mmmsa221.github.io) | https://mmmsa221.github.io/ |
| Análisis de Cabida | `cabida` | [mmmsa221/AnalisisCabida](https://github.com/mmmsa221/AnalisisCabida) | https://mmmsa221.github.io/AnalisisCabida/ |
| Simulación de Plan de Inversión | `simulador` | este repo, carpeta `simulador/` | https://mmmsa221.github.io/simulador/ |
| Licitaciones | `licitaciones` | este repo, carpeta `licitaciones/` | https://mmmsa221.github.io/licitaciones/ |
| Tablero de Loteos Natania 360 | `loteos` | [mmmsa221/Ecipsa-Loteos](https://github.com/mmmsa221/Ecipsa-Loteos) | https://mmmsa221.github.io/Ecipsa-Loteos/ (tiene su propio ingreso) |

## Cómo trabajar en los repos

- **Desde GitHub:** entrar con la cuenta `mmmsa221` (o una con permiso de escritura) y editar o subir archivos ("Add file → Upload files"). Al guardar en `main`, el sitio se actualiza solo en 1 o 2 minutos.
- **Desde una computadora:** `git clone https://github.com/mmmsa221/mmmsa221.github.io` (o `.../AnalisisCabida`), cambiar, `git push` a `main`.
- **Desde Claude:** el proyecto "Centro de Mando Planificación" tiene el inventario del hall. Pedile a Claude que conecte el repo (`mmmsa221/mmmsa221.github.io` o `mmmsa221/AnalisisCabida`) con permiso de escritura.
- Los repos son **públicos**: nunca subir mails, contraseñas ni la clave `service_role` de Supabase.

## Archivos de este repo

| Archivo | Qué es |
|---|---|
| `index.html` | Login, recuperación y cambio de contraseña, y las tarjetas (lista `HERRAMIENTAS`). |
| `sesion.js` | Sesión compartida. Cada herramienta lo incluye y llama a `ECI.exigir('<código>')`. |
| `eci.css` | Sistema visual común (barra, láminas, campos, botones). |
| `sql/010_grupos.sql` | Grupos de acceso en Supabase (quién ve qué). |
| `docs/ACCESOS.md` | Cómo dar de alta personas, armar grupos y sumar herramientas. |

## Supabase

Un solo proyecto, el "Supabase de Herramientas" (`xwprtfxtrwcyrzdiamvd`), maneja usuarios, permisos y los datos de Cabida y del Simulador. La clave que aparece en `sesion.js` es la pública: la protección la dan las políticas RLS.

El Tablero de Loteos usa **otro** Supabase y sus propios usuarios.
