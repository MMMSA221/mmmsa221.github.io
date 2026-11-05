"""Regenera entregas/datos.js a partir del export de stock de Dynamics.

Uso:  python entregas/actualizar_datos.py "Stock_Productos_NATANIA_Y_MA_dd-mm-aaaa.xlsx"

Toma la hoja "Productos activo Puntuales ..." y deja solo viviendas
(Casa, Casa Futura, Dúplex, Departamento) de emprendimientos Natania,
sin MilAires ni emprendimientos de terceros.
"""
import json
import re
import sys
from datetime import datetime
from pathlib import Path

import pandas as pd

VIVIENDAS = ['Casa', 'Casa Futura', 'Departamento', 'Duplex', 'Departamento con pileta']
PROVINCIAS = {'Cordoba': 'Córdoba', 'Tucuman': 'Tucumán', 'Neuquen': 'Neuquén', 'Central': 'Central (Paraguay)'}
FECHA = 'Fecha Entrega Planificada (técnica)'


def limpiar(v):
    return re.sub(r'\s+', ' ', str(v)).strip() if pd.notna(v) else None


def etapa(r):
    e = limpiar(r['Etapa'])
    if e and e.lower() != 'sin etapa':
        return re.sub(r'\betapa\b', 'Etapa', e)
    ed = limpiar(r['Edificio'])
    if ed and str(r['Tipo Inmueble']).startswith('Departamento'):
        return ed  # los edificios casi nunca tienen etapa: se agrupan por torre
    return 'Sin etapa'


def corte_desde_nombre(nombre):
    m = re.search(r'(\d{1,2})-(\d{1,2})-(\d{4})', nombre)
    return f'{m.group(3)}-{int(m.group(2)):02d}-{int(m.group(1)):02d}' if m else datetime.now().strftime('%Y-%m-%d')


def main(xlsx):
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
    salida = {'corte': corte_desde_nombre(Path(xlsx).name), 'viviendas': filas}
    destino = Path(__file__).with_name('datos.js')
    destino.write_text('window.DATOS = ' + json.dumps(salida, ensure_ascii=False, separators=(',', ':')) + ';\n', encoding='utf-8')
    print(f'{len(filas)} viviendas, corte {salida["corte"]} -> {destino}')


if __name__ == '__main__':
    main(sys.argv[1])
