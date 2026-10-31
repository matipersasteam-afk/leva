# Mensaje de WhatsApp para LEVA

Mandalo en este orden: 1) el texto, 2) el video, 3) el PDF. El link ya va en el texto.

---

¡Hola, [Nombre]! ¿Cómo estás? 👋

Te comparto algo que armé para LEVA: la app oficial de sus torneos, con su marca, para que los jugadores se inscriban y paguen, sigan el cuadro y el ranking, y tú lleves todo el día del torneo desde un solo lugar.

Primero el video, dura poco más de un minuto 🎾
Después te dejo la presentación en PDF y el link para que la pruebes tú mismo:
https://leva-padel-app.web.app/prototipo/

¿Te late que lo probemos en tu próximo torneo?

---

**Antes de mandarlo:**
- Cambiá `[Nombre]` por el nombre del organizador.
- Adjuntá `LEVA-demo.mp4` y `LEVA-presentacion.pdf` (los dos están en esta carpeta).
- El precio se edita al inicio de `leva-presentacion.html` (línea `const PRECIO = '[PRECIO A CONFIRMAR]';`). Después regenerá el PDF con este comando en PowerShell, desde `C:\leva\presentacion`:

```powershell
& "C:\Program Files\Google\Chrome\Application\chrome.exe" --headless --no-pdf-header-footer --virtual-time-budget=5000 "--print-to-pdf=$PWD\LEVA-presentacion.pdf" "file:///C:/leva/presentacion/leva-presentacion.html"
```
