// Crea el torneo de demostración "LEVA Open Otoño" (abierto, sin inscripciones).
// Uso: node tools/seed_demo.mjs   ·   borrar: node tools/seed_demo.mjs borrar
import { execSync } from 'node:child_process';

const P = 'leva-padel-app';
const ID = 'demo-leva-open-otono';
const BASE = `https://firestore.googleapis.com/v1/projects/${P}/databases/(default)/documents`;
const NAME = `projects/${P}/databases/(default)/documents`;
const token = execSync('gcloud auth print-access-token', { encoding: 'utf8', shell: true }).trim();
const H = { Authorization: `Bearer ${token}`, 'x-goog-user-project': P, 'Content-Type': 'application/json' };

if (process.argv[2] === 'borrar') {
  execSync(`firebase firestore:delete "events/${ID}" --recursive --force --project ${P}`, { stdio: 'inherit', shell: true });
  process.exit(0);
}

const S = (v) => ({ stringValue: v }), I = (v) => ({ integerValue: String(v) }), B = (v) => ({ booleanValue: v });
const N = { nullValue: null }, T = (d) => ({ timestampValue: d.toISOString() });
const M = (fields) => ({ mapValue: { fields } }), A = (...values) => ({ arrayValue: { values } });
const at = (y, m, d, h, min = 0) => new Date(Date.UTC(y, m - 1, d, h + 6, min)); // hora de Guadalajara

const writes = [{ update: { name: `${NAME}/events/${ID}`, fields: {
  name: S('LEVA Open Otoño'), slug: S('leva-open-otono'), status: S('open'),
  venue: M({ name: S('Arena LEVA'), address: S('Zapopan, Jal.') }),
  startDate: T(at(2026, 11, 14, 8)), endDate: T(at(2026, 11, 16, 22)), registrationDeadline: T(at(2026, 11, 10, 23, 59)),
  courts: A(...[1, 2, 3, 4].map((i) => M({ id: S(`c${i}`), name: S(`Cancha ${i}`) }))),
  rules: M({ goldenPoint: B(true), superTiebreak: B(true), setsToWin: I(2), gamesPerSet: I(6), tiebreakPoints: I(7), superTiebreakPoints: I(10) }),
  matchMinutes: I(60), minRestMinutes: I(60), checkInMinutesBefore: I(20), paymentMethods: A(S('venue')),
  schemaVersion: I(1),
} }, updateTransforms: [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }, { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }] }];

[['tercera', '3ra', 16, 'groups_knockout'], ['cuarta', '4ta', 16, 'groups_knockout'], ['quinta', '5ta', 16, 'groups_knockout'],
 ['sexta', '6ta', 16, 'single_elim'], ['suma9', 'Suma 9', 12, 'relampago']].forEach(([id, name, cap, format], order) => {
  writes.push({ update: { name: `${NAME}/events/${ID}/categories/${id}`, fields: {
    name: S(name), capacity: I(cap), priceCents: I(140000), format: S(format), formatConfig: M({}), order: I(order),
    confirmedCount: I(0), waitlistCount: I(0), drawStatus: S('none'), lastRegId: N,
  } } });
});

const r = await fetch(`${BASE}:commit`, { method: 'POST', headers: H, body: JSON.stringify({ writes }) });
console.log(r.ok ? 'Torneo demo "LEVA Open Otoño" listo.' : await r.text());
