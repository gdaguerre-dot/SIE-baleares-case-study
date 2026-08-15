# QA — historia real de un bug

Esta carpeta documenta un ciclo real de detección y corrección de un bug en `docs/dashboard.html`, como evidencia de proceso de trabajo (no solo del resultado final).

## El reporte

Al probar el dashboard publicado, el usuario reportó: *"al seleccionar Ibiza no figura ningún dato"*. Una captura de pantalla mostró el selector marcando **"Ibiza"**, con los gráficos en blanco pero los KPIs mostrando números que en realidad correspondían a **Formentera** (la última isla probada antes).

## Diagnóstico

La primera hipótesis razonable — un bug en la lógica de agregación o en los datos de Eivissa — se descartó con un test automatizado (`test-select-illa.js`, Playwright) que simula la selección de cada isla y verifica que no haya errores de JS ni datos vacíos. **Los cinco escenarios pasaron sin error.**

La pista real estaba en la propia captura: la interfaz estaba en **castellano** ("Isla", "Resueltas"), cuando el archivo original está en **catalán** ("Illa", "Resoltes"). Eso reveló que el navegador (Chrome) estaba **traduciendo automáticamente la página** — incluyendo el texto de las opciones del `<select>`, que no tenían un atributo `value` explícito. Al traducir "Eivissa" → "Ibiza", el `value` que el navegador enviaba al hacer `change` ya no coincidía con la clave `"Eivissa"` del objeto de datos embebido, y la función de renderizado fallaba silenciosamente a mitad de camino: destruía los gráficos anteriores pero nunca llegaba a crear los nuevos.

## La corrección

1. `value` explícito en cada `<option>`, independiente del texto visible.
2. `translate="no"` en el `<select>` y en `<html>`, para que Chrome no intervenga el control.
3. Fallback defensivo en `render()`: si la clave no existe en los datos, usa `'Totes'` en vez de fallar.

## Por qué queda documentado

No es un bug de lógica de negocio ni de los datos — es una interacción entre una funcionalidad del navegador (traducción automática) y una decisión de implementación (opciones sin `value` explícito). El diagnóstico se hizo con evidencia (test automatizado que descarta la hipótesis de datos/lógica) antes de mirar la causa real, en vez de adivinar directamente sobre el código.

## Archivos

- `mock_chart.js` — stub mínimo de la API de Chart.js, usado para poder ejecutar la lógica de `dashboard.html` en un entorno sin acceso a red (sin depender del CDN real) y así aislar errores propios de errores de carga de red.
- `test-select-illa.js` — test Playwright que carga `dashboard.html`, selecciona cada una de las 5 islas y verifica que no haya excepciones de JS ni datos inconsistentes.

## Cómo correr el test

Requiere Node.js y Playwright instalados (`npm install playwright && npx playwright install chromium`):

```bash
node qa/test-select-illa.js
```

Salida esperada: 5 bloques (uno por isla) sin errores listados.
