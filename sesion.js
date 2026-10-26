/* Sesión única de las herramientas de Grupo ECIPSA.
   Todas las páginas viven en https://mmmsa221.github.io/ (mismo origen), así que comparten la sesión.
   Uso en cada herramienta, en el <head>:
     <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.js"></script>
     <script src="/sesion.js"></script>
     <script>ECI.exigir('cabida');</script>      // oculta la página hasta validar; sin sesión vuelve al hall
   Después: await ECI.listo  → { sesion, usuario }   ·   await ECI.token()  → token para llamar a Supabase */
(function () {
  var SB_URL = 'https://xwprtfxtrwcyrzdiamvd.supabase.co';
  var SB_KEY = 'sb_publishable_HOL_2wM5kz2tPr7t8oTJWQ_X2pRapkh';
  var HALL = '/';
  var client = window.supabase.createClient(SB_URL, SB_KEY, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, storageKey: 'eci-sesion' }
  });

  function usuario(s) {
    if (!s) return null;
    var m = s.user.app_metadata || {};
    return { id: s.user.id, email: s.user.email, nombre: m.nombre || s.user.email, rol: m.rol || 'user', herramientas: m.herramientas || [] };
  }
  async function sesion() { var r = await client.auth.getSession(); return r.data.session; }

  var resolver;
  var ECI = {
    SB_URL: SB_URL, SB_KEY: SB_KEY, client: client, usuario: usuario, sesion: sesion,
    listo: new Promise(function (ok) { resolver = ok; }),
    token: async function () { var s = await sesion(); return s ? s.access_token : null; },
    // Encabezados para la API REST de Supabase con el usuario logueado
    headers: async function () { var t = await ECI.token(); var h = { apikey: SB_KEY }; if (t) h.Authorization = 'Bearer ' + t; return h; },
    exigir: function (herramienta) {
      document.documentElement.style.visibility = 'hidden';
      sesion().then(function (s) {
        var u = usuario(s);
        if (!u) { location.replace(HALL + '?volver=' + encodeURIComponent(location.pathname + location.search + location.hash)); return; }
        if (herramienta && u.herramientas.indexOf(herramienta) < 0) { location.replace(HALL + '?sin=' + encodeURIComponent(herramienta)); return; }
        document.documentElement.style.visibility = '';
        resolver({ sesion: s, usuario: u });
      }).catch(function () { location.replace(HALL); });
      return ECI.listo;
    },
    salir: async function () { try { await client.auth.signOut(); } catch (e) { } location.replace(HALL); }
  };
  // Si la sesión se cierra en otra pestaña, esta también vuelve al hall
  client.auth.onAuthStateChange(function (ev) { if (ev === 'SIGNED_OUT' && location.pathname !== HALL) location.replace(HALL); });
  window.ECI = ECI;
})();
