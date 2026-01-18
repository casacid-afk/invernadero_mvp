# Invernadero MVP (Android)

## Objetivo
App mínima y confiable para gestionar lotes de un invernadero hidropónico,
priorizando funcionamiento real sobre complejidad técnica.

## Etapas (orden fijo)
1. semillero_calefaccionado
2. bandeja_crianza
3. bancada_inicial
4. bancada_final

## Entidades

### Lote
- id: String
- cultivoKey: String
- cantidadActual: int
- etapaActual: Etapa
- fechaInicioEtapa: DateTime
- fechaSiembra: DateTime
- activo: bool

### Movimiento
- id: String
- loteId: String
- tipo: siembra | traspaso | cosecha | merma
- fecha: DateTime
- cantidad: int?        # solo siembra / cosecha / merma
- etapaOrigen: Etapa?   # solo traspaso
- etapaDestino: Etapa?  # solo traspaso
- anulado: bool

## Reglas de negocio
- Un lote nace activo en etapa semillero_calefaccionado.
- Traspaso:
  - etapaActual = etapaDestino
  - fechaInicioEtapa = fecha
- Cosecha o merma:
  - cantidadActual -= cantidad
  - si cantidadActual <= 0:
    - cantidadActual = 0
    - activo = false
- Nunca se borra información:
  - solo se anulan movimientos
- El stock se calcula desde los lotes activos.
- No hay Firebase ni backend en este MVP.

## Alcance del MVP
INCLUIDO:
- Modelos de dominio
- Motor de lógica (sin UI)
- Datos de prueba en memoria

EXCLUIDO (por ahora):
- Firebase
- Reportes
- Autenticación
- Exportaciones
- UI compleja
