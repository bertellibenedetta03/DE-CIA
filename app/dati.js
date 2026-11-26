// DE CIA · Dati del viaggio di prova
//
// Questo file si può modificare senza toccare il resto dell'app.
// Le voci segnate "DA VERIFICARE" sono ipotesi: vanno controllate
// sul posto o sull'orario di Trenitalia e poi corrette qui.

window.DATI = {
  viaggio: {
    titolo: 'Bevilacqua → Monselice → Ferrara',
    treni: [
      {
        nome: 'Regionale delle 6.44',
        da: 'Bevilacqua',
        partenza: '06:44',
        a: 'Monselice',
        arrivo: '07:21',
        binario_arrivo: '6',
      },
      {
        nome: 'Regionale delle 7.30 per Bologna',
        da: 'Monselice',
        partenza: '07:30',
        binario_partenza: '1',
        a: 'Ferrara',
        arrivo: '08:05', // DA VERIFICARE
      },
    ],
    cambio: 'Monselice',
  },

  // Dove stare sul treno per scendere vicino al sottopasso.
  // DA VERIFICARE: lo osserva Stefano a Monselice (settimana 2).
  carrozza: {
    titolo: 'Stai nella carrozza di testa',
    testo: 'A Monselice scendi vicino al sottopasso: è la strada più corta per il binario 1.',
  },

  // Cosa fare se la coincidenza salta. Inserite a mano (Benedetta, settimana 2).
  alternative: [
    {
      titolo: 'Prossimo treno da Monselice',
      dettaglio: 'Regionale delle 8.27, binario 1',
      arrivo: '09:05', // DA VERIFICARE
      nota: 'Un\'ora dopo il previsto.',
    },
    {
      titolo: 'Bus (esempio)',
      dettaglio: 'Da sostituire con un bus vero Monselice → Ferrara, se esiste',
      arrivo: '—',
      nota: 'DA VERIFICARE',
    },
  ],

  // Agenda inventata del capotreno di prova (settimana 2: Benedetta la riscrive).
  capotreno: {
    nome: 'Capotreno di prova',
    turni: [
      { giorno: 'Lunedì', orario: '05:50 – 13:20', treni: ['6.44 Bevilacqua → Monselice', '8.05 Monselice → Mantova', '11.10 Mantova → Monselice'] },
      { giorno: 'Martedì', orario: '05:50 – 13:20', treni: ['6.44 Bevilacqua → Monselice', '8.05 Monselice → Mantova', '11.10 Mantova → Monselice'] },
      { giorno: 'Mercoledì', orario: 'Riposo', treni: [] },
      { giorno: 'Giovedì', orario: '13:40 – 21:10', treni: ['14.10 Monselice → Mantova', '17.44 Mantova → Monselice'] },
      { giorno: 'Venerdì', orario: '05:50 – 13:20', treni: ['6.44 Bevilacqua → Monselice', '8.05 Monselice → Mantova', '11.10 Mantova → Monselice'] },
      { giorno: 'Sabato', orario: '06:30 – 12:00', treni: ['6.44 Bevilacqua → Monselice', '9.30 Monselice → Mantova'] },
      { giorno: 'Domenica', orario: 'Riposo', treni: [] },
    ],
  },
};
