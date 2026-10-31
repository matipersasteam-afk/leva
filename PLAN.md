# LEVA · Plan técnico del MVP (Fase 1)

> Estado: **propuesta para aprobación**. No hay código Flutter todavía.
> Referencia visual oficial: `prototipo/leva-app.html` + `DESIGN.md` (tokens exactos en `.impeccable/design.json`).
> Prototipo publicado: https://claude.ai/artifact/T5jwBXYidDQ2QyEw6Hs8J6

---

## 1. Arquitectura

```
┌──────────────────────────── Flutter (un solo código) ────────────────────────────┐
│  App iOS / Android (jugador · admin · juez)        Flutter Web (Firebase Hosting) │
│  ─ go_router con rutas por rol                      ─ /tv/{eventId}  (pública)    │
│  ─ Riverpod (estado)                                ─ /c/{slug}      (cuadro vivo)│
│  ─ design system LEVA (lib/core/design_system)      ─ /i/{code}      (invitación) │
│  ─ dominio puro en Dart (lib/domain): marcador,     ─ (futuro) /overlay/{matchId} │
│    draw, horarios → testeado sin Flutter                                          │
└───────────────┬──────────────────────────────────────────────────┬───────────────┘
                │ SDKs Firebase                                     │ listeners en tiempo real
        ┌───────▼────────┐  ┌──────────────┐  ┌─────────────┐  ┌───▼──────────┐
        │ Auth           │  │ Firestore    │  │ Storage     │  │ FCM          │
        │ Apple/Google/  │  │ datos + reglas│ │ fotos perfil│  │ push         │
        │ correo         │  └──────▲───────┘  └─────────────┘  └───▲──────────┘
        └────────────────┘         │ triggers / escrituras de servidor │
                          ┌────────┴───────────────────────────────────┴──┐
                          │ Cloud Functions (TypeScript, Node)             │
                          │ ─ pagos: preferencia Mercado Pago, checkout    │
                          │   Stripe, webhooks → marca "pagado"            │
                          │ ─ aceptar invitación, lista de espera          │
                          │ ─ avanzar ganador al confirmar resultado       │
                          │ ─ push: "arranca en 15 min", cambios, resultado│
                          │ ─ roles (custom claims admin/staff)            │
                          └────────────────────────────────────────────────┘
```

Decisiones clave:

- **Un solo organizador.** No hay multi-tenant: una sola app y un solo proyecto de Firebase. La marca vive en `lib/core/design_system/` (tokens + tema) y en `assets/brand/`.
- **La lógica crítica es Dart puro** (`lib/domain`, sin imports de Flutter ni Firebase). Cubre el marcador de pádel, la generación de draw y la generación y recálculo de horarios. Se testea con `flutter test` sin emulador. La app la usa así:
  - El juez calcula el marcador con el motor de dominio en el celular.
  - El admin genera el draw y los horarios en su dispositivo y los escribe en un batch atómico. Las reglas de seguridad solo se lo permiten a un admin.
- **El servidor solo hace lo que el cliente no puede hacer de forma confiable:** cobrar, recibir webhooks, mandar push, avanzar al ganador cuando la pareja rival confirma y asignar roles.
- **Tiempo real:** `snapshots()` de Firestore en el cuadro, el marcador, los horarios y la TV. Sin servidor propio de websockets.
- **Rutas públicas sin cuenta** (TV y cuadro en vivo): leen solo colecciones con datos públicos (partidos con nombres desnormalizados). Nunca leen inscripciones ni pagos.

## 2. Gestión de estado: **Riverpod** (`flutter_riverpod`, sin generación de código)

| Por qué Riverpod | Detalle |
|---|---|
| Encaja con Firestore en tiempo real | `StreamProvider` por documento o consulta, con `autoDispose`: se cancela el listener al salir de la pantalla. |
| Testeable | Los providers se sobreescriben en tests (repositorios fake) sin tocar widgets. |
| Sin `BuildContext` | Los servicios (pagos, push) leen estado desde cualquier lado. |
| Liviano para tu PC de 8 GB | **Sin `build_runner`** (ni riverpod_generator, freezed ni json_serializable). Los modelos se escriben a mano con `fromMap`/`toMap` y `copyWith`. Así se evita el proceso más pesado del ecosistema Flutter. |

Descartados: **Bloc** (mucho boilerplate para un equipo de una persona), **Provider** (el sucesor natural es Riverpod) y **GetX** (acopla navegación, estado y DI; difícil de testear).

## 3. Modelo de datos de Firestore

Convenciones:
- Los montos van en **centavos MXN** (`int`).
- Las fechas van en `Timestamp` UTC; la UI muestra hora de Guadalajara (America/Mexico_City).
- `createdAt` y `updatedAt` en todo.
- `schemaVersion` en documentos raíz.

### 3.1 Colecciones

```
users/{uid}
  displayName, nickname, photoUrl, phone?
  category: '3ra'|'4ta'|'5ta'|'6ta'|'suma9'|…   (string libre controlada por catálogo)
  clubId, clubName                               (desnormalizado)
  hand: 'diestra'|'zurda'
  position: 'drive'|'reves'|'ambas'
  rankingPoints: int  (cache; fase 2 lo calcula el circuito)
  stats: { tournaments: int, titles: int }
  ambassador: bool = false                       (fase 2)
  role (solo lectura; la fuente real es el custom claim): 'player'|'staff'|'admin'
  └─ fcmTokens/{token}  { platform, updatedAt }
  └─ history/{eventId}  { eventName, categoryName, partnerName, result: 'campeon'|'final'|'semis'|…, date }

clubs/{clubId}             { name, city }       (para la regla "no cruzar mismo club")

events/{eventId}
  name, slug (para /c/{slug}), status: 'draft'|'open'|'closed'|'live'|'finished'
  venue: { name, address, mapsUrl }
  startDate, endDate, registrationDeadline
  courts: [{ id:'c1', name:'Cancha 1' }, …]
  rules: { goldenPoint: bool, superTiebreak: bool, setsToWin: 2, tiebreakAt: 6 }
  matchMinutes: 60, minRestMinutes: 60, checkInMinutesBefore: 20
  paymentMethods: ['mercadopago','stripe','venue']
  scheduleRevision: int                           (sube en cada recálculo)
  circuitId?, seasonId?                           (fase 2: ranking del Circuito LEVA)
  sponsorIds: []                                  (fase 2, se muestra en TV desde el MVP con logos)
  public: { name, venueName, dates }              (subset seguro para rutas públicas)

events/{eventId}/categories/{categoryId}
  name: '4ta', capacity: 16, priceCents: 140000
  format: 'groups_knockout'|'single_elim'|'americano'|'relampago'
  formatConfig: { groupSize: 4, qualifiersPerGroup: 2, … }
  confirmedCount, waitlistCount                   (contadores mantenidos por Function)
  drawStatus: 'none'|'draft'|'published'

events/{eventId}/registrations/{regId}            (PRIVADO: jugadores de la pareja + admin/staff)
  categoryId
  playerUids: [uidA, uidB?]                        (array para consultas array-contains)
  players: [{ uid, name, clubId, ranking }]        (snapshot al inscribirse)
  status: 'pending_partner'|'pending_payment'|'confirmed'|'waitlist'|'cancelled'
  invite: { code, invitedUid?, expiresAt, acceptedAt? }
  availability: [{ day:'2026-11-14', slots:['manana','tarde','noche'] }]   (por jugador, se intersecta)
  payment: {
    method: 'mercadopago'|'stripe'|'venue',
    split: 'full'|'half',
    status: 'pending'|'paid'|'refunded',
    amountCents, paidCents,
    providerRef?, paidAt?, markedByUid?            (staff cuando cobra en sede)
  }
  seed?: int, waitlistPosition?: int
  checkIn: { [uid]: Timestamp }

invites/{code}            { eventId, regId, fromUid, categoryId, expiresAt }   (para el link /i/{code})

events/{eventId}/groups/{groupId}                 (PÚBLICO)
  categoryId, name:'A', teams: [{ regId, label:'Gasparini / De Anda' }]

events/{eventId}/matches/{matchId}                (PÚBLICO: solo nombres, nada privado)
  categoryId, stage:'group'|'knockout'|'americano', groupId?, round:int, order:int
  teamA: { regId, label, playerUids:[…] }, teamB: {…}  (null mientras sea "Por definir")
  playerUids: [4 uids]                             (para "mis partidos")
  next: { matchId, slot:'A'|'B' }?                 (llave)
  courtId?, scheduledAt?, estimatedAt?             (estimatedAt cambia con atrasos)
  status: 'scheduled'|'called'|'live'|'pending_confirmation'|'final'|'walkover'
  score: { sets:[[6,4],[3,6]], games:[3,2], points:[2,1], server:0|1, tiebreak:bool, superTiebreak:bool }
  rulesSnapshot: { goldenPoint, superTiebreak }
  result: { winner:'A'|'B', submittedBy, submittedAt, confirmedBy?, confirmedAt?, disputed?:bool }
  version: int                                     (control de concurrencia en el marcador)
  youtubeVideoId?, highlights:[]                   (fase 2)
  └─ points/{autoId}  { by:'A'|'B', scoreAfter, kind:'point'|'golden'|'game'|'set', at, byUid }
                                                    (log para "Últimos puntos"; fase 2 lo usa el overlay)

events/{eventId}/live/tv                          (PÚBLICO, lo escribe staff)
  call: { matchId, courtId, at }?                  (dispara "llamado a cancha")
  celebration: { matchId, at }?                    (dispara la animación dorada)
  slideOverride?: 'cuadro'|'en_juego'|'proximos'|'sponsors'

payments/{paymentId}      (SOLO servidor) { eventId, regId, provider, providerId, status, amountCents, raw, createdAt }

sponsors/{sponsorId}      (fase 2 ampliada; en MVP solo logo para la TV) { name, logoUrl, tier, active }

— FASE 2 (se diseña ahora, no se construye) —
circuits/{circuitId}/seasons/{seasonId}/rankings/{uid}  { points, eventsPlayed, bestResults[] }
badges/{badgeId}         { name:'Embajador LEVA'|'Campeón Relámpago'|'X torneos', rule }
users/{uid}/badges/{badgeId}  { awardedAt, eventId? }
ambassadors/{uid}        { featuredOrder, bio, socials }
plates/{plateId}         { type:'bienvenida'|'clasificados'|'campeones'|'story', eventId?, imageUrl }
```

### 3.2 Índices compuestos (`firestore.indexes.json`)

| Colección | Campos | Para qué |
|---|---|---|
| matches | `categoryId` ASC, `round` ASC, `order` ASC | cuadro por categoría |
| matches | `courtId` ASC, `scheduledAt` ASC | grilla de horarios y recálculo |
| matches | `status` ASC, `scheduledAt` ASC | "en juego" y "próximos" (TV) |
| matches | `playerUids` CONTAINS, `scheduledAt` ASC | "mis partidos" |
| registrations | `categoryId` ASC, `status` ASC, `createdAt` ASC | panel admin y lista de espera (orden de llegada) |
| registrations | `playerUids` CONTAINS, `status` ASC | "mis inscripciones" |
| registrations | `payment.status` ASC, `categoryId` ASC | filtro pagado / pendiente |
| collectionGroup matches | `playerUids` CONTAINS, `scheduledAt` ASC | historial y próximos partidos en todos los eventos |

## 4. Reglas de seguridad por rol

Los roles van como **custom claims** (`request.auth.token.role`): `admin`, `staff` o ninguno (jugador). Solo una Function invocada por un admin puede asignarlos. El primer admin se asigna con un script único.

| Recurso | Jugador | Juez/staff | Admin | Público sin cuenta |
|---|---|---|---|---|
| `users/{uid}` | lee perfiles; escribe solo el suyo (sin `role`, `rankingPoints` ni `stats`) | lee | lee/escribe | — |
| `events`, `categories` | lee | lee | escribe | lee si `status != draft` |
| `registrations` | crea la suya; lee y edita las suyas (disponibilidad, cancelar); **nunca** `payment.status` | lee; marca `payment` en sede y `checkIn` | todo | — |
| `invites/{code}` | lee por código exacto (`get`, no `list`) | — | todo | — |
| `groups`, `matches` | lee; **propone** resultado o confirma si juega ese partido (solo `result.*`, `status → pending_confirmation/final`) | escribe `score`, `status`, `points` de cualquier partido | todo (draw y horarios en batch) | lee |
| `live/tv` | — | escribe | escribe | lee |
| `payments` | — | — | lee | — |

Reglas complementarias:
- Las validaciones de forma (tipos, enums, montos que no cambian) van en las reglas.
- Lo que no se puede validar en reglas lo hace una Function: el marcador solo avanza un punto por escritura (`version + 1`), y el estado de pago lo cambia solo el webhook o el staff.
- Storage: `users/{uid}/avatar.jpg` lo escribe solo el dueño, solo imágenes de 5 MB como máximo.
- Las reglas se prueban con el **emulador de Firestore** (requiere Java; es opcional en tu PC, ver §9).

## 5. Estructura de carpetas

```
leva/
├─ prototipo/leva-app.html          referencia visual (no se toca salvo pedido)
├─ PRODUCT.md · DESIGN.md · PLAN.md
├─ app/                             proyecto Flutter
│  ├─ pubspec.yaml
│  ├─ assets/brand/                 escudo, wordmark (provisorios → oficiales)
│  ├─ assets/fonts/Archivo[wdth,wght].ttf, Archivo-Italic[wdth,wght].ttf   (OFL, variable)
│  ├─ lib/
│  │  ├─ main.dart · app.dart       bootstrap Firebase + router
│  │  ├─ l10n/app_es_MX.arb         textos (gen_l10n nativo, sin build_runner)
│  │  ├─ core/
│  │  │  ├─ design_system/          tokens.dart, colors.dart, typography.dart, motion.dart,
│  │  │  │                          theme.dart (ThemeData + ThemeExtension LevaTokens),
│  │  │  │                          widgets/ (LevaButton, Chamfer, GoldText, DuelCard, Chip,
│  │  │  │                          Tag, SegControl, Panel, ScoreBox, BracketMatch, TabBar…)
│  │  │  ├─ router/                 rutas + guards por rol
│  │  │  └─ utils/                  fechas es-MX, formato de dinero
│  │  ├─ domain/                    ⚠ Dart puro, sin Flutter ni Firebase
│  │  │  ├─ scoring/                padel_score.dart (punto de oro/ventaja, TB, súper TB)
│  │  │  ├─ draw/                   seeding.dart, groups.dart, knockout.dart, americano.dart,
│  │  │  │                          relampago.dart, club_separation.dart
│  │  │  ├─ schedule/               scheduler.dart (canchas, disponibilidad, descanso),
│  │  │  │                          delay.dart (recálculo y diff de afectados)
│  │  │  └─ models/                 entidades inmutables (Team, Match, Slot, Rules…)
│  │  ├─ data/                      repositorios Firestore/Storage/Functions + mapeos
│  │  └─ features/
│  │     ├─ auth/ profile/ events/ registration/ payments/
│  │     ├─ draw/ schedule/ match/ checkin/ notifications/
│  │     ├─ admin/ judge/
│  │     └─ tv/                     solo web
│  ├─ test/domain/                  tests de marcador, draw, horarios
│  ├─ web/                          index.html, íconos, .well-known (app links)
│  └─ android/ ios/
├─ functions/                       TypeScript
│  ├─ src/ payments/ invites/ matches/ notifications/ roles/
│  └─ test/
├─ firestore.rules · firestore.indexes.json · storage.rules · firebase.json · .firebaserc
└─ .env.example                     solo nombres de variables, sin valores
```

Secretos: las claves de Mercado Pago y Stripe y los secretos de webhook van con **Firebase Functions secrets** (`defineSecret`, guardados en Secret Manager). Nunca van en el repo ni en la app. La app solo lleva la configuración pública de Firebase (`firebase_options.dart`), que no es secreta.

## 6. Dependencias (todas con justificación; nada fuera de esta lista sin preguntarte)

### App Flutter
| Paquete | Para qué |
|---|---|
| `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `cloud_functions`, `firebase_messaging` | stack pedido |
| `flutter_riverpod` | estado (§2) |
| `go_router` | rutas, deep links (`/i/{code}`, `/c/{slug}`, `/tv/{id}`), guards por rol |
| `sign_in_with_apple`, `google_sign_in` | login. Apple es obligatorio en iOS si ofrecés Google (guía 4.8) |
| `flutter_local_notifications` | mostrar push con la app abierta en Android y el canal "Partidos" |
| `mobile_scanner` | el staff escanea el QR de check-in |
| `qr_flutter` | el jugador muestra su QR |
| `image_picker` | foto de perfil |
| `url_launcher` | abrir el checkout de Mercado Pago o Stripe (Custom Tabs / Safari View Controller) |
| `share_plus` | compartir el link de invitación y el del cuadro |
| `intl` + `flutter_localizations` (SDK) | fechas, horas y montos en es-MX |
| `cached_network_image` | fotos de jugadores y logos de sponsors |

Fuentes: **Archivo variable incluida como asset** (licencia OFL) en lugar del paquete `google_fonts`. Así funciona sin internet en la sede y permite los ejes `wdth`/`wght` con `FontVariation`.

### Dev
`flutter_test` (SDK) y `flutter_lints`. Sin `build_runner`.

### Functions (Node/TypeScript)
`firebase-admin`, `firebase-functions`, `mercadopago` (SDK oficial), `stripe`. Dev: `typescript`, `jest` o `vitest` (uno solo, a definir al llegar a pagos).

## 7. Pantallas del MVP (todas ya existen en el prototipo)

| # | Pantalla | Rol | Ruta |
|---|---|---|---|
| 1 | Splash | todos | `/` |
| 2 | Login (Apple / Google / correo) | todos | `/login` |
| 3 | Inicio: próximo partido + torneos + en juego | jugador | `/inicio` |
| 4 | Detalle de evento + categorías + lista de espera | jugador | `/evento/:id` |
| 5 | Inscripción en pareja + disponibilidad | jugador | `/evento/:id/inscripcion` |
| 6 | Pago (Mercado Pago · tarjeta Stripe · **pago en sede**) | jugador | `/inscripcion/:regId/pago` |
| 7 | Perfil + historial LEVA (+ editar perfil) | jugador | `/perfil`, `/jugador/:uid` |
| 8 | Cuadro (grupos / eliminatoria) | todos + público | `/evento/:id/cuadro`, web `/c/:slug` |
| 9 | Horarios (mis partidos / todos, aviso de atraso) | jugador | `/evento/:id/horarios` |
| 10 | Partido en vivo | todos | `/partido/:id` |
| 11 | Check-in QR (jugador muestra; staff escanea) | jugador / staff | `/checkin`, `/staff/escanear` |
| 12 | Admin · crear/editar evento y categorías | admin | `/admin/evento/:id` (no estaba en el prototipo; formulario estándar con el design system) |
| 13 | Admin · inscripciones pagado/pendiente (+ cobrar en sede) | admin/staff | `/admin/evento/:id/inscripciones` |
| 14 | Admin · generar y ajustar draw | admin | `/admin/evento/:id/draw` |
| 15 | Admin · horarios con arrastrar y soltar + atraso | admin | `/admin/evento/:id/horarios` |
| 16 | Juez · cargar resultado (punto a punto / final) | staff + jugadores | `/juez/partido/:id` |
| 17 | Pantalla TV | público (web) | `/tv/:eventId` |

La pantalla 12 no estaba en el prototipo. El brief pide que el admin cree eventos, así que hace falta. La hago con los mismos componentes y te la muestro antes de cerrar ese módulo.

## 8. Orden de construcción

Cada módulo cierra con `flutter analyze` sin issues, los tests de dominio en verde, revisión de Impeccable y reporte. Después de cada uno **me detengo**.

| Fase / módulo | Contenido | Depende de ti |
|---|---|---|
| **F2 · Base** | `flutter create`, design system traducido del prototipo, pantalla de muestra de componentes | — |
| **M1 · Motor de marcador** | `domain/scoring` + tests exhaustivos (oro, ventaja, TB 7, súper TB 10, deshacer) | — |
| **M2 · Firebase + Auth + perfil** | proyecto Firebase, login, perfil, foto, roles | **crear/vincular el proyecto de Firebase** (te pregunto antes); cuenta Apple Developer para Sign in with Apple |
| **M3 · Eventos + inscripción** | admin crea evento y categorías; pareja por link o usuario; disponibilidad; lista de espera; **pago en sede** | — |
| **M4 · Draw** | motor (4 formatos, siembra, separación por club) + tests + UI admin + cuadro | — |
| **M5 · Horarios** | motor (canchas, disponibilidad, descanso) + recálculo por atraso + tests + drag & drop | — |
| **M6 · Resultados en vivo** | juez punto a punto o resultado final, confirmación rival, avance de llave, cuadro público `/c/:slug` | plan **Blaze** (Functions) |
| **M7 · Check-in QR** | QR del jugador + escáner del staff | — |
| **M8 · Pantalla TV** | `/tv/:eventId` en Flutter Web: rotación, llamado a cancha, celebración | dominio o subdominio si lo querés propio |
| **M9 · Push** | tokens, "arranca en 15 min", cambios de horario, resultados | cuenta Apple (APNs key) |
| **M10 · Pagos en línea** | Mercado Pago + Stripe vía checkout web + webhooks + panel | **cuentas de Mercado Pago y Stripe de LEVA** |

Por qué este orden:
- Primero va lo que no depende de cuentas externas.
- Los tres motores críticos (marcador, draw y horarios) se construyen y testean temprano.
- Los pagos en línea van al final porque dependen de las cuentas comerciales de LEVA. Mientras tanto, el torneo puede correr con **pago en sede**, que el admin marca como pagado.

## 9. Entorno (Windows, 8 GB)

- **Desarrollo:** Flutter Web en Chrome y un celular Android físico por USB, en lugar del emulador de Android Studio, que consume unos 2–3 GB.
- **Emulador de Firestore** (para probar reglas): requiere Java y unos 500 MB. Lo uso solo en el módulo de reglas, y te pregunto antes de instalar Java si no lo tenés.
- **iOS:** compilar y firmar requiere una Mac (propia, rentada, o CI tipo Codemagic). Lo vemos al acercarnos a la publicación.
- `flutter analyze` y `flutter test` corren bien en 8 GB, y sin `build_runner` no hay procesos de generación de código.

## 10. Lo que es incierto o requiere tu decisión (no lo supongo)

1. **Apple y los pagos.** La guía **3.1.5(a)** dice que los bienes y servicios que se consumen fuera de la app deben cobrarse con métodos distintos a la compra dentro de la app. Inscribirse a un torneo presencial encaja ahí. Lo que encontré son interpretaciones de la comunidad en los foros de Apple, no un fallo oficial para este caso, así que conviene redactar bien la nota para App Review. Fuentes: [Apple Developer Forums 3.1.5(a)](https://developer.apple.com/forums/thread/127700), [hilo sobre bienes fuera de la app](https://developer.apple.com/forums/thread/126112).
2. **Google Play.** Hasta donde sé, su política de pagos excluye de Play Billing los bienes y servicios físicos. Lo confirmo en la documentación vigente antes de M10.
3. **Mercado Pago México.** Hay guía oficial de Checkout Pro para Flutter: el backend crea la preferencia y la app abre el flujo web con Custom Tabs o Safari View Controller ([guía MX](https://www.mercadopago.com.mx/developers/pt/docs/checkout-pro-preferences/mobile-integration/flutter.md), [notificaciones](https://www.mercadopago.com.mx/developers/es/docs/checkout-api-orders/notifications?scope=prod)).
   - **No encontré las comisiones 2026.** Hay que verlas en la cuenta de LEVA.
   - **Hay que confirmar** si los webhooks de preferencias funcionan igual que los de órdenes.
4. **Firebase.** Cloud Functions, las tareas programadas (push de "15 min") y, desde 2026, Cloud Storage requieren el **plan Blaze**, de pago por uso con cuota gratis ([guía](https://dev.to/androve2k/spark-vs-blaze-the-firebase-pricing-guide-i-wish-id-read-sooner-onb), fuente no oficial: lo verifico en la página de precios al crear el proyecto). Para un torneo, el costo esperado es muy bajo, pero requiere tarjeta.
5. **Links de invitación.** Firebase Dynamic Links ya no existe, así que uso App Links (Android) y Universal Links (iOS) con el dominio de Firebase Hosting. Si LEVA tiene dominio propio, mejor.
6. **Decisiones de producto pendientes:**
   - Plazo para pagar en sede antes de liberar el lugar a la lista de espera.
   - Si dividir el pago 50/50 aplica también en sede.
   - Quién resuelve un resultado en disputa (propongo el admin).
   - Duración por formato (relámpago y americano son más cortos).
7. **Assets oficiales:** logo, colores exactos, fotos recortadas y logos de sponsors. Hoy son provisorios.

## 11. Cambios al prototipo después de tu aprobación

- Agregado **pago en sede** (efectivo o tarjeta en la mesa de control). El lugar queda apartado como "pendiente" y el staff lo marca pagado desde el panel de inscripciones.
- Vista de celular a pantalla completa, con el índice de pantallas en un cajón.

## 12. Módulos nuevos

> Estado: **propuesta**. Cambia el esquema aprobado de Firestore, así que no se toca código Flutter ni reglas hasta que lo apruebes. Cubre el **Bloque A (día del torneo · organizador)**, el **Bloque B (jugador)** en 12.4–12.6 y el **Bloque C (comunidad)** en 12.7–12.9.

### 12.1 Colecciones y campos (Bloque A)

```
events/{eventId}
  + dayConfig: { toleranceMinutes: 15, minRestMinutes: 30, dayStart:'08:00', dayEnd:'23:00', slotMinutes: 15 }
  + voceo: { mode:'auto'|'approve', voiceId, jingle:true }

events/{eventId}/categories/{categoryId}
  + color: 'open'|'1'|…|'s9'                                   (token de categoría del calendario)

events/{eventId}/matches/{matchId}
  + courtId?, scheduledAt?  → null = "sin asignar" (bandeja del calendario)
  + durationMinutes: 60
  + status: se suma 'late' calculado en cliente (scheduled + 5 min sin llamar); no se guarda
  + call: {
      calledAt, calledByUid,
      secondCallAt?, defaultWarningAt?,                (los marca la Function de tolerancia)
      defaultProposedAt?, proposedLoser?: 'A'|'B'|'both',
      extraMinutes: 0,                                 ("Anular · +5 min")
      checkIn: { A?: Timestamp, B?: Timestamp },       (QR de cada pareja; con ambas se detiene el cronómetro)
      stoppedAt?
    }
  + walkover: { loser:'A'|'B'|'both', confirmedByUid, at }   (default: SIEMPRE lo confirma un juez)
  + scheduleLog/{autoId}  { from:{courtId,scheduledAt}, to:{…}, byUid, reason:'drag'|'delay'|'tray', notifiedUids:[], at }

events/{eventId}/announcements/{autoId}           (cola del voceo; la lee la laptop del parlante)
  kind: 'call'|'second_call'|'default_warning'|'default_confirmed'|'result'|'sponsor'|'quick'|'free'|'reminder'
  text, matchId?, sponsorId?
  status: 'pending_approval'|'queued'|'playing'|'done'|'skipped'|'discarded'
  audioUrl?                                       (MP3 generado por la Function; caché por texto)
  order: int, createdAt, playedAt?, createdByUid? (null = automático)

users/{uid}
  + pronunciation: string                          ("Cómo se pronuncia mi nombre"; el voceo lo usa en lugar del nombre)

sponsors/{sponsorId}
  + mentionRounds: ['semifinal','final']           ("Esta final es presentada por…")
```

Índices nuevos: `matches` (`courtId` ASC, `scheduledAt` ASC, `status` ASC) para la grilla y "próximos 5 por cancha"; `matches` (`status` ASC, `call.calledAt` ASC) para la torre; `announcements` (`status` ASC, `order` ASC) para la cola.

### 12.2 Cloud Functions (Bloque A · requieren plan Blaze)

| Function | Disparador | Qué hace |
|---|---|---|
| `toleranceTick` | Cloud Tasks por partido llamado (min 5, 10 y tolerancia) | Marca segundo llamado, advertencia y **propuesta** de default; encola los avisos. Nunca aplica el default. |
| `onMatchCalled` | `matches` update → `status:'called'` | Encola el llamado (con mención de sponsor en semifinal/final) y programa las tareas de tolerancia. |
| `onCheckIn` | escritura de `call.checkIn` | Con ambas parejas: `stoppedAt` y cancela tareas pendientes. |
| `confirmWalkover` (callable, juez/admin) | botón del juez | Aplica el default, avanza la llave y encola el aviso. |
| `onResultConfirmed` | `result.confirmedAt` | Avanza la llave. Encola el aviso de resultado. |
| `rescheduleCourt` (callable, admin) | "Atrasar desde aquí" +15/+30 | Corre en transacción los partidos siguientes de la cancha, sube `scheduleRevision`, escribe `scheduleLog` y manda push a los afectados. Devuelve la lista de avisados. |
| `validateMove` (callable) | soltar en la grilla | Devuelve conflictos: cancha ocupada, jugador en dos partidos a la vez, descanso menor al mínimo. La UI decide deshacer o mantener. |
| `voceoTts` (callable) | cada aviso nuevo | Texto → voz con un servicio de IA (ElevenLabs u OpenAI TTS), guarda el MP3 en Storage y escribe `audioUrl`. La clave vive en Secret Manager. |

### 12.3 Orden sugerido de construcción en Flutter (Bloque A)

1. Dominio puro (`lib/domain/schedule`): grilla de 15 min, choque de cancha, conflictos de jugador y descanso, "atrasar desde aquí". Con tests.
2. Dominio de tolerancia (`lib/domain/tolerance`): estados por minuto y propuesta de default. Con tests.
3. Calendario de canchas para tablet (grilla, bandeja, arrastrar y la alternativa tocar + tocar, filtros) usando el dominio del paso 1.
4. Tolerancia y check-in con QR (escáner del staff).
5. Torre de control (lecturas en tiempo real, alertas ordenadas y acciones).
6. Voceo: cola en Firestore, reproductor en Flutter Web para la laptop del parlante y `voceoTts`.
7. Vista TV del calendario (`/tv/{eventId}/calendario`).

### 12.4 Colecciones y campos (Bloque B · jugador)

```
circuits/{circuitId}/seasons/{seasonId}
  pointsTable: { campeon:1000, finalista:600, semifinal:360, cuartos:180, octavos:90, grupos:45 }
  multipliers: { circuito:1, master:2 }   (los Relámpago no suman puntos)
  windowDays: 365, bestOf: 6, titlesToPromote: 2
  master: { qualifiersPerCategory: 8, dates }

users/{uid}/rankingResults/{eventId_categoryId}   (lo escribe la Function al cerrar el evento)
  eventId, eventName, eventType:'relampago'|'circuito'|'master', date, category, round:'campeon'|…, points, partnerUid

rankings/{seasonId}_{category}/players/{uid}      (PÚBLICO, desnormalizado para la tabla)
  displayName, points, counted:[eventId…], position, previousPosition, updatedAt
rankings/{seasonId}_{category}/pairs/{regId}      (para el Máster: suma de los dos jugadores)

users/{uid}
  + categories: ['4ta','suma9']   + promotions: [{ from, to, at, titleEventIds:[…] }]
  + stats: { played, won, streak, bestPartnerUid }   (cache de la Function)
  + memberNumber: '0427'   + walletPass?: { appleSerial, googleObjectId }   (fase de producción)
```

### 12.5 Cloud Functions (Bloque B)

| Function | Disparador | Qué hace |
|---|---|---|
| `onEventFinished` | evento → `finished` | Escribe `rankingResults` de cada jugador según su ronda final. |
| `recomputeRanking` | después de `onEventFinished` y diario (vence la ventana de 12 meses) | Usa el mismo motor que el prototipo (`LevaRanking`: mejores 6, 12 meses, multiplicador), guarda posición y posición anterior, y la tabla de parejas del Máster. |
| `checkPromotion` | dentro de `recomputeRanking` | 2 títulos en 12 meses → agrega la categoría nueva, guarda el ascenso y manda push. El historial no se borra. |
| `seedDraw` (ya en M4) | generar draw | Toma la suma de puntos de la pareja como siembra. |
| `walletPass` (callable) | botones de Wallet | Genera el pase de Apple (.pkpass firmado) o el enlace "Guardar en Google Wallet" (JWT firmado). Detalle en §12.10. |

### 12.6 Orden sugerido en Flutter (Bloque B)

1. `lib/domain/ranking` en Dart: port 1:1 de `LevaRanking` con el mismo caso de prueba (10 verificaciones).
2. Tabla de ranking + detalle "qué te suma" + banner del Máster.
3. Estadísticas del perfil y gráfica.
4. Credencial con QR (el mismo QR del check-in) + botones de Apple y Google Wallet (§12.10).

### 12.7 Colecciones y campos (Bloque C · comunidad)

```
events/{eventId}/predictions/{uid}       { picks:{ [matchId]:'A'|'B' }, champions:{ [categoryId]: regId }, points, updatedAt }
events/{eventId}/predictionBoard/{uid}   (PÚBLICO) { displayName, points, rank }
events/{eventId}/prizes/{rank}           { sponsorId, description }
events/{eventId}/highlights/{clipId}     { round, matchId, courtId, title, thumbUrl, videoUrl?, source:'replay_cam', votes:int }
events/{eventId}/highlightVotes/{uid_round}  { clipId, at }   (id compuesto = 1 voto por usuario y ronda)
events/{eventId}/vendors/{vendorId}      { standNumber, name, category, fee:{ amountCents, status:'pendiente'|'pagado' } }
```

### 12.8 Cloud Functions (Bloque C)

| Function | Qué hace |
|---|---|
| `lockPredictions` | Al pasar un partido a `live` cierra sus pronósticos (las reglas de seguridad también impiden escribir después de `startedAt`). |
| `scorePredictions` | Con cada resultado confirmado suma 10 pts por acierto y 50 por campeón, y actualiza la tabla pública. |
| `castHighlightVote` (callable) | Un voto por usuario y ronda (documento con id compuesto). Al cerrar la ronda marca la ganadora y la manda a la TV. |
| `ingestReplayClip` | **Futuro:** recibe los clips de las cámaras de replay y crea el `highlight`. |

### 12.9 Orden sugerido en Flutter (Bloque C)

1. Pronósticos (partidos y campeones) + tabla + premios.
2. Jugada del torneo con votación; slide en `/tv/{eventId}`.
3. Panel admin de emprendedores y cobro de su lugar.

### 12.10 Apple Wallet y Google Wallet (credencial)

El prototipo ya muestra el flujo completo (vista previa del pase, agregar, estado "En tu Wallet"). En producción lo resuelve una sola Function con dos salidas. **Ninguna clave vive en la app:** certificados y cuenta de servicio van en Secret Manager.

**Contenido del pase (igual en ambas plataformas)**

| Campo | Valor | Se actualiza con |
|---|---|---|
| Nombre | `users.displayName` | cambio de perfil |
| Categoría | categoría principal actual | `checkPromotion` |
| Ranking | posición en su categoría | `recomputeRanking` |
| Nº de jugador | `users.memberNumber` | — |
| Próximo partido | día · hora · cancha | `rescheduleCourt`, sorteo del draw |
| Código | QR = mismo token del check-in | — |
| Ubicación | coordenadas de la sede del evento activo (pantalla de bloqueo) | alta de evento |

**Apple Wallet**
- Tipo de pase `generic`, `passTypeIdentifier: pass.mx.leva.credencial`, `serialNumber` = uid, `barcodes[0].format: PKBarcodeFormatQR`, `locations` con la sede, colores LEVA (fondo navy, etiquetas oro).
- `walletPass({ platform: 'apple' })` arma `pass.json` + íconos, firma el manifiesto (PKCS#7) con el certificado Pass Type ID + el certificado WWDR de Apple y devuelve el `.pkpass` (Storage con URL firmada de corta vida). Flutter lo abre con `add_to_wallet` / PassKit.
- Actualizaciones: `webServiceURL` apunta a una Function HTTPS (`walletWebService`) que implementa los endpoints de registro de dispositivos y entrega del pase nuevo; al cambiar ranking, categoría o partido se manda un push APNs vacío con el certificado del pase.
- Colección: `walletDevices/{deviceLibraryId}_{serial}` `{ uid, pushToken, registeredAt }`.

**Google Wallet**
- Clase `GenericClass` `{issuerId}.leva_credencial_2026` (una por temporada) y objeto `GenericObject` `{issuerId}.{uid}` con `cardTitle`, `header`, `textModulesData` (categoría, ranking, nº, próximo partido), `barcode` QR y `hexBackgroundColor` navy.
- `walletPass({ platform: 'google' })` firma un JWT `savetowallet` con la cuenta de servicio del emisor y devuelve `https://pay.google.com/gp/v/save/{jwt}`; Flutter abre el enlace o usa el botón oficial.
- Actualizaciones: `PATCH` al `GenericObject` vía Wallet API desde las mismas Functions; no hace falta push propio.

**Function nueva**

| Function | Disparador | Qué hace |
|---|---|---|
| `walletSync` | `onWrite` de `rankings/.../players/{uid}`, `users/{uid}` (categoría) y partidos asignados | Si el usuario tiene `walletPass`, actualiza el objeto de Google y avisa a Apple (APNs) para que pida el pase nuevo. |
| `walletWebService` (HTTPS) | llamadas de iOS | Registro / baja de dispositivos y entrega del `.pkpass` actualizado. |

**Lo que LEVA tiene que tramitar (no lo puede hacer la app):**
1. Apple Developer Program (cuenta de organización) → crear Pass Type ID y descargar su certificado.
2. Google Pay & Wallet Console → cuenta emisora aprobada + cuenta de servicio de Google Cloud con acceso a la Wallet API.
3. Plan Blaze (las Functions llaman a servicios externos).


### 12.11 Colecciones y campos (operación y jugador · torneo de octubre)

> Propuesta: cambia el esquema aprobado; requiere tu OK antes de tocar Flutter o reglas.

```
events/{eventId}
  + duplicatedFrom?: eventId   + status: 'borrador'|'abierto'|'en_curso'|'terminado'
  + finance: { costs: { canchas, pelotas, premios, staff, app, procesador } }   (centavos MXN, editable por admin)
  └─ checklistPhases/{phaseId} { name, order }                       (el organizador crea, renombra, reordena y elimina fases)
  └─ checklist/{taskId}      { phaseId, title, ownerUid?, dueAt?, notes?, status:'pendiente'|'en_curso'|'listo', order, updatedAt }
checklistTemplates/{orgId}   { phases:[{ name, tasks:[{ title, ownerUid?, notes? }] }], updatedAt }   ("Guardar como plantilla"; sin documento = plantilla original)
  └─ waivers/{uid}           (PRIVADO: dueño + admin) { name, acceptedAt, textVersion, ip?, userAgent? }
  └─ broadcasts/{id}         { segment:{ type:'categoria'|'pagado'|'pendiente'|'juegan_manana'|'sin_checkin', value? },
                               channel:'push'|'whatsapp', text, templateName?, recipients:int, sendAt, status:'programado'|'enviado'|'error', createdBy }
waiverTexts/{version}        { body, legalReviewed:false, createdAt }   ("Borrador: revisar con un abogado" hasta que legalReviewed = true)
whatsappSessions/{phoneHash}        { uid, lastInboundAt }   (ventana de 24 h para respuestas libres)
```

### 12.12 Cloud Functions (operación y jugador)

| Function | Disparador | Qué hace |
|---|---|---|
| `financeReport` (callable, admin) | abrir el reporte | Suma inscripciones pagadas, sponsors firmados y lugares de emprendedores; resta gastos; compara con el evento anterior. |
| `duplicateEvent` (callable, admin) | botón Duplicar | Copia categorías, precios, formatos, sponsors y la plantilla de checklist guardada (tareas en "pendiente", sin fechas) a un evento nuevo en estado borrador con las fechas elegidas. |
| `onRegistrationCreate` | inscripción nueva | Rechaza la inscripción si el jugador no tiene `waivers/{uid}` del evento. |
| `sendBroadcast` (callable) + `scheduledBroadcasts` (cada minuto) | enviar o programar | Resuelve el segmento a uids, manda push (FCM) o plantilla de WhatsApp y guarda el conteo. |
| `matchCalendarIcs` (HTTPS) | botón "Agregar a mi calendario" | Devuelve el `.ics` con los partidos del jugador (zona America/Mexico_City); opcional: URL de suscripción que se actualiza sola. |
| `whatsappWebhook` (HTTPS) | mensaje entrante de Meta | Bot: "mi horario", "mi cancha", "pagar", "resultados". Los avisos que inicia LEVA (llamado a cancha, recordatorios, masivos) salen como plantillas aprobadas. |

**Pendiente de LEVA:** cuenta de WhatsApp Business Platform (Meta) con número verificado y plantillas aprobadas (`llamado_cancha`, `segundo_llamado`, `aviso_torneo`, `recordatorio_responsiva`); revisión legal de la carta responsiva.

### 12.13 Orden sugerido en Flutter (operación y jugador)

1. Carta responsiva como paso obligatorio de la inscripción + lista del admin.
2. Lista de torneos con duplicar y checklist por fases.
3. Reporte financiero.
4. "Agregar a mi calendario".
5. Mensajes masivos segmentados.
6. Bot de WhatsApp (cuando Meta apruebe las plantillas).

### 12.14 Colecciones y campos (sponsors)

> Propuesta: cambia el esquema aprobado; requiere tu OK antes de tocar Flutter o reglas. Sponsors del prototipo: NIKE (principal y ranking), EVIAN (agua oficial y marcador oficial), NATURA (categoría patrocinada y cupones) y EVENTOS SAN MATEO (premiación, momentos clave y spots entre sets); las 4 canchas llevan su nombre. Una marca por rubro. Sus logos oficiales los sube LEVA en el alta (`logoPath`) con autorización de cada marca; sin logo se muestran nombre e iniciales, nunca un logo dibujado. Precios de ejemplo ("Ejemplo, ajustar").

```
sponsors/{sponsorId}               { name, shortName, rubro, color, logoPath?, exclusive:bool, contactEmail?, createdAt }
events/{eventId}
  └─ sponsorPackages/{pkgKey}      { name:'Principal'|'Oro'|'Plata'|'Cancha'|'Categoría'|'Proveedor oficial', priceCents, carouselSec,
                                     spotsPerHour, spaces:[{ key, title, where, frequency }], isExample:true }
  └─ sponsorSlots/{slotId}         { pkgKey, label, court?:int, category?:string, extraSpaces?:[...], sponsorId?:id, soldAt? }   (inventario; una marca puede tener varios lugares)
  └─ sponsorSettings               { maxSpotsPerHour:2, autoSpots:true }
  └─ spots/{id}                    { sponsorId, text, seconds (10–15), status:'aprobado'|'pendiente', airedAt[] }
  └─ coupons/{id}                  { sponsorId, title, expiresAt, source:'inscripcion'|'qr_cancha' }
      users/{uid}/coupons/{id}     { couponId, code, redeemedAt?, redeemedBy? }
  └─ courtQr/{court}               { sponsorId?, offer, url }
  └─ exposure/{sponsorId}          { voiceMentions, tvSeconds, bannerViews, notifOpens, platesShared, qrScans, couponsRedeemed }
  └─ exposureReports/{sponsorId}   { generatedAt, summary, metrics, shareToken }   (vista para el sponsor sin datos de otras marcas)
```

### 12.15 Cloud Functions (sponsors)

| Function | Disparador | Qué hace |
|---|---|---|
| `onSponsorWrite` | alta o edición | Rechaza si otro sponsor del mismo rubro existe y alguno tiene exclusividad. |
| `assignSlot` (callable, admin) | Asignar en inventario | Transacción: marca el lugar como vendido solo si sigue libre; actualiza `finance` del evento. |
| `scheduledSpots` (cada minuto) | reloj del torneo | Encola un spot en `announcements` solo si no se superó `maxSpotsPerHour` y no hay avisos urgentes en cola. |
| `onAnnouncementCreate` | aviso nuevo | Bloquea sponsor en avisos de emergencia y default; cuenta menciones por sponsor. |
| `redeemCoupon` (callable, staff del stand) | escaneo del QR | Valida código de un solo uso y lo marca canjeado. |
| `exposureAggregate` (onWrite de eventos de exposición) | uso de la app/TV/voceo | Suma contadores en `exposure/{sponsorId}`. |
| `generateExposureReports` | evento → `terminado` | Crea un reporte por sponsor con resumen en una frase y enlace para compartir. |
| `renderSharePlate` (HTTPS) | Compartir placa | Genera la imagen (resultado, avance, campeón) con el logo del sponsor de placas. |

**Reglas que valida el servidor:** el sponsor nunca va en cancha, horario ni marcador (solo en su propia fila); máximo un banner por pantalla; avisos de emergencia y default sin sponsor; un solo sponsor por rubro con exclusividad.

### 12.16 Orden sugerido en Flutter (sponsors)

1. Alta de sponsors, paquetes e inventario (admin).
2. Espacios en la app: pantalla de carga, categoría patrocinada, ranking, banner, línea en notificaciones.
3. TV: banda inferior, carrusel con tiempo garantizado, logo en el llamado, punto de campeonato, marcador.
4. Voceo: cancha patrocinada, "presentada por", "cortesía de", spots con máximo por hora.
5. Mis beneficios con QR y QR por cancha.
6. Placas para compartir y reporte de exposición.

**Marcador de cancha y fotos:** pantalla 16:9 por cancha (`courts/{court}/display` lee `events/{eventId}/matches/{matchId}` con onSnapshot; sin sponsors ni otros partidos) y paso "Foto para el marcador" en el check-in del partido: recorte de fondo en el dispositivo (Vision en iOS, ML Kit Subject Segmentation en Android) o en una Cloud Function `cutoutPhoto`, guardado en `matches/{matchId}/photos/{uid}`.
