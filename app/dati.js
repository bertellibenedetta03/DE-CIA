// DE CIA · Dati del viaggio di prova
//
// Questo file si può modificare senza toccare il resto dell'app.
//
// ORARI VERI. Fonte: orario ufficiale Trenitalia pubblicato sul National Access
// Point italiano (CCISS), convertito in formato GTFS da github.com/deryclem/trenitalia-gtfs
// (licenza CC BY 4.0), versione del 20 novembre 2026, valida fino all'11 dicembre 2027.
// Controllato anche su orario-treni.it (stazione di Bevilacqua).
//
// Attenzione: dal 13 dicembre 2026 cambia l'orario invernale. Il treno per Bologna
// parte da Monselice alle 7.29 invece che alle 7.30, quindi il cambio passa da 9 a 8 minuti.
// L'app sceglie da sola gli orari giusti in base alla data.
//
// Ancora DA VERIFICARE (non sono nei dati ufficiali): i binari, la carrozza consigliata,
// i minuti per attraversare la stazione.

(function () {
  const oggi = new Date();
  const nuovoOrario = oggi >= new Date('2026-12-13T00:00:00+01:00');

  window.DATI = {
    fonte: 'Orario ufficiale Trenitalia (dati aperti GTFS), aggiornato al 20/11/2026',
    viaggio: {
      titolo: 'Bevilacqua → Monselice → Ferrara',
      treni: [
        {
          nome: 'Regionale 16955 Mantova → Venezia Mestre',
          numero: '16955',
          da: 'Bevilacqua',
          partenza: '06:44',
          a: 'Monselice',
          arrivo: '07:21',
          fermate: 'Montagnana 6.50 · Saletto 7.01 · Ospedaletto Euganeo 7.07 · Este 7.13',
          giorni: 'Dal lunedì al sabato',
          binario_arrivo: '6', // DA VERIFICARE: dalla nostra ricerca, non è nei dati ufficiali
        },
        {
          nome: 'Regionale Veloce 3963 Venezia → Bologna',
          numero: '3963',
          da: 'Monselice',
          partenza: nuovoOrario ? '07:29' : '07:30',
          binario_partenza: '1', // DA VERIFICARE: dalla nostra ricerca
          a: 'Ferrara',
          arrivo: '08:16',
          fermate: 'Rovigo 7.58',
          giorni: 'Tutti i giorni',
        },
      ],
      cambio: 'Monselice',
      cambio_min: nuovoOrario ? 8 : 9,
    },

    // Il disegno del treno e la carrozza giusta per scendere vicino alle scale.
    // DA VERIFICARE a Monselice (settimana 2, Stefano): quante carrozze ha il treno,
    // se il numero sopra le porte parte da 1 in testa, dove sono le scale del sottopasso.
    treno: {
      carrozze: 4, // DA VERIFICARE
      carrozza_giusta: 1, // DA VERIFICARE: 1 = la prima in testa
      uscita: 'scale del sottopasso',
      verificato: false, // mettere true quando i dati sono stati controllati sul posto
    },

    // Cosa fare se la coincidenza salta (orari veri, stessa fonte).
    alternative: [
      {
        titolo: 'Prossimo treno diretto',
        dettaglio: `Regionale Veloce 3965 per Bologna, parte da Monselice alle ${nuovoOrario ? '8.29' : '8.27'}`,
        arrivo: '09:03',
        nota: '47 minuti dopo il previsto.',
      },
      {
        titolo: 'Con cambio a Rovigo',
        dettaglio: 'Regionale 17017 da Monselice alle 8.09, a Rovigo alle 8.33; poi il Regionale Veloce 3965 alle 8.48',
        arrivo: '09:03',
        nota: 'Stessa ora di arrivo: utile solo se vuoi muoverti subito.',
      },
    ],
    nota_alternative: 'Nei dati Trenitalia non ci sono bus da Monselice a Ferrara. Un bus di un\'altra azienda è ancora da cercare.',

    // Agenda inventata del capotreno di prova (settimana 2: Benedetta la riscrive).
    capotreno: {
      nome: 'Capotreno di prova',
      turni: [
        { giorno: 'Lunedì', orario: '05:20 – 12:50', treni: ['16955 Mantova 5.37 → Venezia Mestre', 'Ritorno verso Mantova (inventato)'] },
        { giorno: 'Martedì', orario: '05:20 – 12:50', treni: ['16955 Mantova 5.37 → Venezia Mestre', 'Ritorno verso Mantova (inventato)'] },
        { giorno: 'Mercoledì', orario: 'Riposo', treni: [] },
        { giorno: 'Giovedì', orario: '13:40 – 21:10', treni: ['Turno pomeridiano (inventato)'] },
        { giorno: 'Venerdì', orario: '05:20 – 12:50', treni: ['16955 Mantova 5.37 → Venezia Mestre', 'Ritorno verso Mantova (inventato)'] },
        { giorno: 'Sabato', orario: '05:20 – 12:50', treni: ['16955 Mantova 5.37 → Venezia Mestre'] },
        { giorno: 'Domenica', orario: 'Riposo (il 16955 non circola)', treni: [] },
      ],
    },
  };
})();
