# Casa in missione — MVP

Una prima versione responsiva per trasformare le faccende condivise in missioni con prove fotografiche e punti.

## Architettura prevista

- **Interfaccia:** HTML/CSS/JavaScript senza build step; mobile-first.
- **Identità e dati condivisi:** Supabase Auth + PostgreSQL con Row Level Security (schema iniziale in `schema.sql`).
- **Foto:** bucket Supabase Storage privato; URL firmati a breve durata, mai URL pubblici.
- **Punti:** ledger append-only; assegnazione all'approvazione e addebito al riscatto tramite RPC transazionali lato database.
- **Rotazione:** assegnazione settimanale deterministica che distribuisce ogni mansione tra i membri attivi, con data d'inizio settimana memorizzata per non riassegnare duplicati.
- **Ruoli e social:** admin della casa approva gli ingressi e gestisce missioni e premi; profili con avatar; storico personale e bacheca delle prove visibile ai coinquilini.
- **Scambi, feed e missioni settimanali:** `MISSION_SOCIAL_FEATURES.sql` aggiunge riassegnazione admin, scambi con bonus pari alla differenza punti e didascalie. `AUTO_APPROVE_MISSIONS.sql` completa la missione e accredita i punti subito dopo l’invio della foto. `WEEKLY_MISSION_SKIP.sql` permette all’admin di sospendere una missione per la settimana corrente; la prossima rotazione la riattiva automaticamente.

## Avvio

Apri `index.html` in un browser con connessione internet. La demo non richiede account o server: usa dati di esempio e conserva le modifiche nel local storage del browser. Registrazione e accesso sono una simulazione e non devono essere usati per password reali. Invio foto, revisione, punteggio, registro, riscatto e premi sono esplorabili in locale.

## Collegamento a un backend reale

1. Crea un progetto Supabase e applica `schema.sql` dal SQL Editor.
2. Crea un bucket **privato** chiamato `mission-proofs`; aggiungi policy Storage che consentano upload all'assegnatario e lettura ai soli membri della stessa casa. Limita i file a immagini e dimensione ragionevole.
3. Implementa RPC transazionali per: creare una casa e membership owner, unirsi con codice invito, generare le assegnazioni settimanali, approvare/rifiutare una prova, assegnare punti una sola volta e riscattare premi solo se il saldo basta.
4. Inserisci URL e chiave anonima Supabase nel blocco iniziale di `app.js`. La chiave anonima è pubblica per definizione: RLS deve essere attiva su ogni tabella e bucket. **Non inserire mai una service-role key nel browser.**
5. Sostituisci il repository locale della demo con le query/RPC Supabase e genera URL firmati per visualizzare le prove.
6. Pubblica su un host HTTPS statico solo dopo aver configurato dominio, redirect URL email e le policy RLS/Storage.

## Stato e limiti attuali

Il client usa il progetto Supabase configurato in `app.js` con la sola chiave Publishable. La chiave è prevista per il browser; le tabelle hanno RLS e le operazioni che assegnano o spendono punti passano da funzioni SQL. `schema.sql` è lo script iniziale e **non va rilanciato** su un progetto già inizializzato: usa la verifica di `information_schema` o crea una migrazione separata.

In modalità connessa ogni account crea una casa (diventandone admin) oppure chiede di entrare con un codice; l'admin approva l'accesso. Missioni, premi, richieste, punti e profili sono caricati dal database. Prove e avatar vengono caricati nel bucket privato e letti tramite URL firmati. Per una casa già attiva, esegui una sola volta `MISSION_SOCIAL_FEATURES.sql` nel SQL Editor Supabase; aggiunge le funzioni sociali senza eliminare dati. Per le conferme email di Supabase, l'utente conferma l'indirizzo e poi accede di nuovo per completare l'iscrizione alla casa. La modalità demo locale resta disponibile solo se le credenziali Supabase vengono rimosse.
