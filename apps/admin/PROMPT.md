---
id: PROMPT
aliases: []
tags: []
---

1. Luego de darle "play", veo que los trades se procesasan y persisten,
   pero yo no veo los trades u operaciones persistidas (o por lo menos no
   lo veo en Avo), y por otro lado el sidebar derecha el SYSTEM STATE
   - a pesar de que el run fue exitoso y sin filas erroneas - sigue
     mostrando que no es confiable, cuando en ese caso debe ser
     "confiable" ya que no tuvo errores.

2. luego de que el archivo sea procesado exitosamente, el boton de play vuelve
   a deshabilitarlo y el input-file deberia limpiarse y volver al icono inicial.

3. Tampoco veo los Top Accounts (live) !! 🙀

## Plan de solucion (diagnostico + implementacion)

### A) System State queda "no confiable" despues de un run exitoso

**Causa raiz**
- En `Admin::Demo::DatasetsController#create` se verifica hash usando una instancia stale de `run` (previa a `Runs::Execute`), y eso deja `verification_status=verification_error`.

**Solucion**
- Usar el run retornado por `Runs::Execute` (o recargar antes de verificar): `run = Runs::Execute.new.call(...)` y luego `Runs::VerifyInputHash.new.call(run.reload)`.
- Mantener `with_timeline_env` para que la verificacion no caiga por timeline flag.

**Validacion**
- Request spec: upload valido termina en `status=succeeded` + `verification_status=verified`.
- System state debe pasar a confiable cuando no hay errores por fila.

### B) El input/icono de upload debe resetearse post-proceso

**Requisito**
- Luego de procesar exitosamente:
  - limpiar file input,
  - volver icono a estado inicial,
  - deshabilitar boton play.

**Solucion**
- En `overview/dataset_actions_controller`, enganchar fin de submit exitoso (Turbo) y ejecutar `clearFile()`.

**Validacion**
- System spec: adjuntar archivo -> play habilitado -> procesar -> input limpio + play disabled + icono inicial.

### C) Top Accounts (live) vacio

**Causa raiz**
- En modo DB-first no hay `result_json_path` canonico y el checkpoint actual trae `state.accounts[].markets` sin `totals`.
- `LiveStateMetrics` hoy exige `totals` para construir top accounts.

**Decision acordada**
- Cuando no haya `totals`, mostrar aproximacion explicita:
  - `realized_net_pnl_quote = 0`
  - `unrealized_pnl_quote` calculado por mark-to-market
  - `total_pnl_quote = unrealized_pnl_quote`

**Solucion**
- Extender `LiveStateMetrics`:
  - si existe `totals`, usarlo (comportamiento actual);
  - si no existe, derivar por cuenta desde `accounts[].markets` + `priceSnapshot.prices` de `run.input_json`.

**Validacion**
- Unit specs para ambos formatos de checkpoint (con y sin `totals`).

### D) Visibilidad de operaciones/trades persistidos en Avo

**Aclaracion de modelo**
- `RunSnapshot` **no** es la tabla de trades; es agregacion diaria por run/fecha.
- Operaciones/eventos persistidos viven en `RunDailyEvent` (payload del evento por secuencia).
- Agregados diarios viven en `RunDailyVolume` y `RunDailyPnl`.

**Plan**
- Mejorar `Avo::Resources::Run` con panel de "Persisted operations" (conteos + links drilldown).
- Crear recursos Avo para inspeccion:
  - `RunSnapshot`
  - `RunDailyEvent`
  - `RunDailyVolume`
  - `RunDailyPnl`

### E) Orden de ejecucion sugerido (commits atomicos)

1. `fix(runs): verify reloaded run and reset upload controls post-process`
2. `feat(overview): add top-accounts fallback without totals`
3. `feat(avo): expose persisted operation tables and run drilldowns`
