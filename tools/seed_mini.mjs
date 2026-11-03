// Mini torneo para la demo con los dueños: 1 categoría (4ta, 8 lugares) con 7 parejas
// de prueba ya inscritas. El lugar 8 queda libre para inscribirse en vivo desde el celular.
// Uso: node tools/seed_mini.mjs   ·   borrar: node tools/seed_mini.mjs borrar
import { execSync } from 'node:child_process';

const P = 'leva-padel-app';
const ID = 'demo-mini-torneo';
const BASE = `https://firestore.googleapis.com/v1/projects/${P}/databases/(default)/documents`;
const NAME = `projects/${P}/databases/(default)/documents`;
const token = execSync('gcloud auth print-access-token', { encoding: 'utf8', shell: true }).trim();
const H = { Authorization: `Bearer ${token}`, 'x-goog-user-project': P, 'Content-Type': 'application/json' };

// Jugadores ficticios (uid con prefijo demo- para reconocerlos y borrarlos).
const PAIRS = [
  [['Diego Ramírez', 'Club Zapopan', 820], ['Andrés Lozano', 'Club Zapopan', 760]],
  [['Mariana Ortiz', 'Pádel Providencia', 900], ['Sofía Navarro', 'Pádel Providencia', 640]],
  [['Luis Herrera', 'Arena LEVA', 700], ['Pablo Cárdenas', 'Club Andares', 690]],
  [['Fernanda Ruiz', 'Club Andares', 610], ['Valeria Campos', 'Arena LEVA', 580]],
  [['Javier Medina', 'Pádel Chapalita', 540], ['Rodrigo Salas', 'Pádel Chapalita', 520]],
  [['Ana Villaseñor', 'Club Zapopan', 480], ['Lucía Ibarra', 'Pádel Providencia', 470]],
  [['Tomás Aguirre', 'Arena LEVA', 430], ['Emilio Fuentes', 'Club Andares', 410]], // pago pendiente
];

const uidsOf = () => PAIRS.flat().map((_, i) => `demo-mini-${i + 1}`);

if (process.argv[2] === 'borrar') {
  execSync(`firebase firestore:delete "events/${ID}" --recursive --force --project ${P}`, { stdio: 'inherit', shell: true });
  const writes = uidsOf().map((u) => ({ delete: `${NAME}/users/${u}` }));
  const r = await fetch(`${BASE}:commit`, { method: 'POST', headers: H, body: JSON.stringify({ writes }) });
  console.log(r.ok ? 'Mini torneo y jugadores de prueba borrados.' : await r.text());
  process.exit(0);
}

const S = (v) => ({ stringValue: v }), I = (v) => ({ integerValue: String(v) }), B = (v) => ({ booleanValue: v });
const N = { nullValue: null }, T = (d) => ({ timestampValue: d.toISOString() });
const M = (fields) => ({ mapValue: { fields } }), A = (...values) => ({ arrayValue: { values } });
const at = (y, m, d, h, min = 0) => new Date(Date.UTC(y, m - 1, d, h + 6, min)); // hora de Guadalajara
const PRICE = 140000;

const writes = [{ update: { name: `${NAME}/events/${ID}`, fields: {
  name: S('Mini Torneo LEVA'), slug: S('mini-torneo-leva'), status: S('open'),
  venue: M({ name: S('Arena LEVA'), address: S('Zapopan, Jal.') }),
  startDate: T(at(2026, 11, 21, 9)), endDate: T(at(2026, 11, 21, 20)), registrationDeadline: T(at(2026, 11, 20, 23, 59)),
  courts: A(...[1, 2].map((i) => M({ id: S(`c${i}`), name: S(`Cancha ${i}`) }))),
  rules: M({ goldenPoint: B(true), superTiebreak: B(true), setsToWin: I(2), gamesPerSet: I(6), tiebreakPoints: I(7), superTiebreakPoints: I(10) }),
  matchMinutes: I(60), minRestMinutes: I(30), checkInMinutesBefore: I(20), paymentMethods: A(S('venue')),
  schemaVersion: I(1),
} }, updateTransforms: [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }, { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }] }];

const uids = uidsOf();
PAIRS.flat().forEach(([name, club, pts], i) => {
  writes.push({ update: { name: `${NAME}/users/${uids[i]}`, fields: {
    displayName: S(name), category: S('4ta'), club: S(club), hand: S('diestra'), position: S(i % 2 ? 'reves' : 'drive'),
    rankingPoints: I(pts), stats: M({ tournaments: I(0), titles: I(0) }), ambassador: B(false), demo: B(true),
  } } });
});

const now = Date.now();
PAIRS.forEach((pair, i) => {
  const paid = i < PAIRS.length - 1;
  const [a, b] = [uids[i * 2], uids[i * 2 + 1]];
  const created = new Date(now - (PAIRS.length - i) * 3600e3);
  writes.push({ update: { name: `${NAME}/events/${ID}/registrations/demo-reg-${i + 1}`, fields: {
    categoryId: S('cuarta'), playerUids: A(S(a), S(b)),
    players: A(M({ uid: S(a), name: S(pair[0][0]), club: S(pair[0][1]) }), M({ uid: S(b), name: S(pair[1][0]), club: S(pair[1][1]) })),
    status: S(paid ? 'confirmed' : 'pending_payment'), slot: S('confirmed'),
    invite: M({ code: S(`DEMO${i + 1}X`), invitedUid: N, acceptedAt: T(created) }),
    availability: M({}),
    payment: M({ method: S('venue'), split: S('full'), status: S(paid ? 'paid' : 'pending'), amountCents: I(PRICE),
      paidCents: I(paid ? PRICE : 0), markedByUid: N, paidAt: paid ? T(created) : N }),
    createdAt: T(created), updatedAt: T(created), demo: B(true),
  } } });
});

writes.push({ update: { name: `${NAME}/events/${ID}/categories/cuarta`, fields: {
  name: S('4ta'), capacity: I(8), priceCents: I(PRICE), format: S('groups_knockout'), formatConfig: M({}), order: I(0),
  confirmedCount: I(PAIRS.length), waitlistCount: I(0), drawStatus: S('none'), lastRegId: S(`demo-reg-${PAIRS.length}`),
} } });

const r = await fetch(`${BASE}:commit`, { method: 'POST', headers: H, body: JSON.stringify({ writes }) });
console.log(r.ok ? `Mini torneo listo: 7 parejas de prueba, 1 lugar libre. https://leva-padel-app.web.app/evento/${ID}` : await r.text());
