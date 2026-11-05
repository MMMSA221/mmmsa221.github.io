"""Carga un export de stock de Dynamics como un corte nuevo del tablero de Entregas.

Uso:  python entregas/actualizar_datos.py "Stock_Productos_NATANIA_Y_MA_dd-mm-aaaa.xlsx" [--corte AAAA-MM-DD]

- Toma la hoja "Productos activo Puntuales ..." y deja solo viviendas: Tipo Inmueble
  Casa y Casa Futura (sin departamentos, dúplex, lotes, cocheras ni locales),
  de emprendimientos Natania, sin MilAires ni emprendimientos de terceros.
- Guarda el corte en entregas/historial/AAAA-MM-DD.json (la fecha sale del nombre
  del archivo o de --corte) y lo suma a entregas/historial/index.json.
- Los cortes anteriores no se tocan: son la base de la comparación entre actualizaciones.
  Volver a cargar la misma fecha reemplaza ese corte.
"""
import json
import re
import sys
from datetime import datetime
from pathlib import Path

import pandas as pd

VIVIENDAS = ['Casa', 'Casa Futura']
PROVINCIAS = {'Cordoba': 'Córdoba', 'Tucuman': 'Tucumán', 'Neuquen': 'Neuquén', 'Central': 'Central (Paraguay)'}
FECHA = 'Fecha Entrega Planificada (técnica)'
COLS = ['id', 'nombre', 'provincia', 'emprendimiento', 'etapa', 'tipo', 'estilo', 'razon', 'avance', 'fecha']
DICT = ['provincia', 'emprendimiento', 'etapa', 'tipo', 'estilo', 'razon', 'avance']  # columnas guardadas como índice
HIST = Path(__file__).with_name('historial')


def limpiar(v):
    return re.sub(r'\s+', ' ', str(v)).strip() if pd.notna(v) else None


def etapa(r):
    e = limpiar(r['Etapa'])
    if e and e.lower() != 'sin etapa':
        return re.sub(r'\betapa\b', 'Etapa', e)
    return 'Sin etapa'


def corte_desde_nombre(nombre):
    m = re.search(r'(\d{1,2})-(\d{1,2})-(\d{4})', nombre)
    return f'{m.group(3)}-{int(m.group(2)):02d}-{int(m.group(1)):02d}' if m else None


def leer(xlsx):
    hojas = pd.ExcelFile(xlsx).sheet_names
    hoja = next(h for h in hojas if h.startswith('Productos'))
    d = pd.read_excel(xlsx, sheet_name=hoja)
    v = d[d['Tipo Inmueble'].isin(VIVIENDAS)]
    v = v[~v['Emprendimiento'].str.contains('MilAires|erceros', case=False, na=False)]
    filas = []
    for _, r in v.iterrows():
        f = r[FECHA]
        filas.append({
            'id': str(r['(No modificar) Prducto']),
            'nombre': limpiar(r['Nombre']),
            'provincia': PROVINCIAS.get(r['Provincia'], r['Provincia']),
            'emprendimiento': limpiar(r['Emprendimiento']),
            'etapa': etapa(r),
            'tipo': r['Tipo Inmueble'],
            'estilo': limpiar(r['Estilo Producto']) or 'Sin estilo',
            'razon': limpiar(r['Razón para el estado']) or 'Sin dato',
            'avance': limpiar(r['Avance de Obra']) or 'Sin dato',
            'fecha': f.strftime('%Y-%m-%d') if pd.notna(f) else None,
        })
    return filas


def compactar(corte, filas):
    dic = {c: sorted({f[c] for f in filas}) for c in DICT}
    pos = {c: {v: i for i, v in enumerate(dic[c])} for c in DICT}
    rows = [[pos[c][f[c]] if c in DICT else f[c] for c in COLS] for f in filas]
    return {'corte': corte, 'cols': COLS, 'dic': dic, 'rows': rows}


def resumen(filas):
    """Conteos por emprendimiento, tipo, razón, avance y año de entrega: alimenta la evolución entre cortes."""
    df = pd.DataFrame(filas)
    df['anio'] = df['fecha'].str[:4]
    g = df.fillna({'anio': ''}).groupby(['emprendimiento', 'provincia', 'tipo', 'razon', 'avance', 'anio']).size().reset_index(name='n')
    return [[r.emprendimiento, r.provincia, r.tipo, r.razon, r.avance, int(r.anio) if r.anio else None, int(r.n)] for r in g.itertuples()]


def main(args):
    xlsx = args[0]
    corte = args[args.index('--corte') + 1] if '--corte' in args else corte_desde_nombre(Path(xlsx).name)
    if not corte:
        sys.exit('No encontré la fecha de corte en el nombre del archivo: pasala con --corte AAAA-MM-DD')
    datetime.strptime(corte, '%Y-%m-%d')
    filas = leer(xlsx)
    HIST.mkdir(exist_ok=True)
    (HIST / f'{corte}.json').write_text(json.dumps(compactar(corte, filas), ensure_ascii=False, separators=(',', ':')), encoding='utf-8')

    idx_path = HIST / 'index.json'
    idx = json.loads(idx_path.read_text(encoding='utf-8')) if idx_path.exists() else {'cortes': []}
    idx['cortes'] = [c for c in idx['cortes'] if c['corte'] != corte]
    idx['cortes'].append({
        'corte': corte,
        'archivo': Path(xlsx).name,
        'cargado': datetime.now().strftime('%Y-%m-%d'),
        'viviendas': len(filas),
        'resumen_cols': ['emprendimiento', 'provincia', 'tipo', 'razon', 'avance', 'anio', 'n'],
        'resumen': resumen(filas),
    })
    idx['cortes'].sort(key=lambda c: c['corte'])
    idx_path.write_text(json.dumps(idx, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(f'Corte {corte}: {len(filas)} viviendas. Cortes guardados: {", ".join(c["corte"] for c in idx["cortes"])}')


if __name__ == '__main__':
    main(sys.argv[1:])
