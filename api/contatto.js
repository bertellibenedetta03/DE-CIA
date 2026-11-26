// DE CIA · Funzione del modulo contatti (Vercel)
//
// Riceve il modulo "Racconta la tua coincidenza", salva il messaggio
// nella tabella "messaggi" di Supabase e manda un'email al team con Resend.
//
// Variabili d'ambiente da impostare su Vercel (Settings → Environment Variables):
//   SUPABASE_URL          es. https://abcd1234.supabase.co
//   SUPABASE_SECRET_KEY   chiave "secret" (sb_secret_...) o "service_role"
//   RESEND_API_KEY        chiave API di Resend (re_...)
//   EMAIL_TEAM            indirizzi che ricevono l'avviso, separati da virgola
//   EMAIL_MITTENTE        (facoltativa) es. "DE CIA <avvisi@tuodominio.it>"
//                         Se manca si usa onboarding@resend.dev (gratis, senza dominio)

const TIPI = ['testimonianza', 'domanda', 'altro'];
const TEMPO_MINIMO_MS = 3000; // chi invia in meno di 3 secondi è quasi sempre un robot

function pulisci(valore, max) {
  if (typeof valore !== 'string') return '';
  return valore.replace(/\u0000/g, '').trim().slice(0, max);
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function rispondi(req, res, status, dati) {
  const vuoleJson = (req.headers.accept || '').includes('application/json');
  if (vuoleJson) return res.status(status).json(dati);
  // Invio senza JavaScript: torna alla pagina con l'esito
  const esito = dati.ok ? 'inviato' : 'errore';
  res.statusCode = 303;
  res.setHeader('Location', `/?${esito}=1#racconta`);
  return res.end();
}

async function salvaSuSupabase(riga) {
  const url = process.env.SUPABASE_URL;
  const chiave = process.env.SUPABASE_SECRET_KEY;
  if (!url || !chiave) throw new Error('Supabase non configurato');

  const headers = {
    apikey: chiave,
    'Content-Type': 'application/json',
    Prefer: 'return=representation',
  };
  // Le vecchie chiavi "service_role" sono JWT e vanno anche in Authorization
  if (chiave.startsWith('eyJ')) headers.Authorization = `Bearer ${chiave}`;

  const r = await fetch(`${url.replace(/\/$/, '')}/rest/v1/messaggi`, {
    method: 'POST',
    headers,
    body: JSON.stringify(riga),
  });
  if (!r.ok) throw new Error(`Supabase ${r.status}: ${await r.text()}`);
  const [salvato] = await r.json();
  return salvato;
}

async function segnaEmailInviata(id) {
  const url = process.env.SUPABASE_URL.replace(/\/$/, '');
  const chiave = process.env.SUPABASE_SECRET_KEY;
  const headers = { apikey: chiave, 'Content-Type': 'application/json' };
  if (chiave.startsWith('eyJ')) headers.Authorization = `Bearer ${chiave}`;
  await fetch(`${url}/rest/v1/messaggi?id=eq.${encodeURIComponent(id)}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({ email_inviata: true }),
  });
}

async function mandaEmail(m) {
  const chiave = process.env.RESEND_API_KEY;
  const destinatari = (process.env.EMAIL_TEAM || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  if (!chiave || destinatari.length === 0) throw new Error('Resend non configurato');

  const mittente = process.env.EMAIL_MITTENTE || 'DE CIA <onboarding@resend.dev>';
  const anteprima = m.messaggio.length > 60 ? m.messaggio.slice(0, 60) + '…' : m.messaggio;

  const righe = [
    ['Tipo', m.tipo],
    ['Nome', m.nome || '(non indicato)'],
    ['Email', m.email || '(non indicata)'],
    ['Tratta', m.tratta || '(non indicata)'],
  ];
  const html = `
    <div style="font-family:Arial,sans-serif;font-size:15px;line-height:1.5;color:#1d1d1b">
      <p style="color:#c8332b;font-weight:bold;margin:0 0 8px">Nuovo messaggio dal sito DE CIA</p>
      <table style="border-collapse:collapse;margin-bottom:16px">
        ${righe
          .map(
            ([k, v]) =>
              `<tr><td style="padding:2px 12px 2px 0;color:#5d5b55">${k}</td><td>${escapeHtml(v)}</td></tr>`
          )
          .join('')}
      </table>
      <div style="white-space:pre-wrap;border-left:3px solid #c8332b;padding-left:12px">${escapeHtml(m.messaggio)}</div>
      <p style="color:#5d5b55;font-size:13px;margin-top:20px">Lo trovi anche su Supabase, tabella <b>messaggi</b> (n. ${escapeHtml(m.id)}).</p>
    </div>`;
  const text =
    righe.map(([k, v]) => `${k}: ${v}`).join('\n') +
    `\n\n${m.messaggio}\n\nSupabase, tabella messaggi, n. ${m.id}`;

  const corpo = {
    from: mittente,
    to: destinatari,
    subject: `[DE CIA] ${m.tipo}: ${anteprima.replace(/\s+/g, ' ')}`,
    html,
    text,
  };
  if (m.email) corpo.reply_to = m.email;

  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${chiave}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(corpo),
  });
  if (!r.ok) throw new Error(`Resend ${r.status}: ${await r.text()}`);
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ ok: false, errore: 'Usa il modulo sul sito.' });
  }

  const b = req.body && typeof req.body === 'object' ? req.body : {};

  // Antispam 1: campo nascosto che solo i robot compilano
  if (pulisci(b.sito_web, 200)) return rispondi(req, res, 200, { ok: true });
  // Antispam 2: modulo inviato troppo in fretta
  const aperto = Number(b.aperto_il);
  if (aperto && Date.now() - aperto < TEMPO_MINIMO_MS) {
    return rispondi(req, res, 200, { ok: true });
  }

  const messaggio = pulisci(b.messaggio, 5000);
  const nome = pulisci(b.nome, 120);
  const email = pulisci(b.email, 200);
  const tratta = pulisci(b.tratta, 200);
  const tipo = TIPI.includes(b.tipo) ? b.tipo : 'testimonianza';
  const consenso = b.consenso === true || b.consenso === 'on' || b.consenso === 'true';

  if (messaggio.length < 5) {
    return rispondi(req, res, 400, { ok: false, errore: 'Scrivi almeno qualche parola.' });
  }
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return rispondi(req, res, 400, { ok: false, errore: 'L’indirizzo email non sembra corretto.' });
  }
  if (!consenso) {
    return rispondi(req, res, 400, { ok: false, errore: 'Serve il consenso per salvare il messaggio.' });
  }

  let salvato;
  try {
    salvato = await salvaSuSupabase({
      nome: nome || null,
      email: email || null,
      tipo,
      tratta: tratta || null,
      messaggio,
      consenso,
    });
  } catch (e) {
    console.error('Salvataggio fallito:', e.message);
    return rispondi(req, res, 500, {
      ok: false,
      errore: 'Non siamo riusciti a salvare il messaggio. Riprova tra poco.',
    });
  }

  // L'email è un avviso: se non parte, il messaggio resta comunque salvato
  try {
    await mandaEmail({ ...salvato, messaggio, nome, email, tratta, tipo });
    await segnaEmailInviata(salvato.id);
  } catch (e) {
    console.error('Email non inviata:', e.message);
  }

  return rispondi(req, res, 200, { ok: true });
};
