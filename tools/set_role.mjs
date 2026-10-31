// Asigna un rol (admin | staff | player) a un usuario existente de Firebase Auth.
// Uso (desde C:\leva):  node tools/set_role.mjs correo@ejemplo.com admin
//
// Usa tu sesión de gcloud (dueño del proyecto); no guarda ni imprime credenciales.
// Es la vía de arranque mientras no haya Cloud Functions (plan Blaze); después
// lo reemplaza una Function que solo un admin puede invocar.
import { execSync } from 'node:child_process';

const PROJECT = 'leva-padel-app';
const [email, role] = process.argv.slice(2);
if (!email || !['admin', 'staff', 'player'].includes(role)) {
  console.error('Uso: node tools/set_role.mjs <correo> <admin|staff|player>');
  process.exit(1);
}

const token = execSync('gcloud auth print-access-token', { encoding: 'utf8', shell: true }).trim();
const api = `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}`;
const headers = {
  Authorization: `Bearer ${token}`,
  'x-goog-user-project': PROJECT,
  'Content-Type': 'application/json',
};

const lookup = await fetch(`${api}/accounts:lookup`, {
  method: 'POST', headers, body: JSON.stringify({ email: [email] }),
}).then((r) => r.json());
const user = lookup.users?.[0];
if (!user) {
  console.error(`No existe una cuenta con ${email}. Esa persona tiene que entrar a la app una vez primero.`);
  process.exit(2);
}

const claims = role === 'player' ? {} : { role };
const res = await fetch(`${api}/accounts:update`, {
  method: 'POST', headers,
  body: JSON.stringify({ localId: user.localId, customAttributes: JSON.stringify(claims) }),
});
if (!res.ok) {
  console.error('No se pudo asignar el rol:', res.status, await res.text());
  process.exit(3);
}
console.log(`Listo: ${email} (${user.localId}) ahora es "${role}". Tiene que cerrar sesión y volver a entrar para que se aplique.`);
