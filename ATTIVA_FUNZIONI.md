# Attivare scambi, feed e riassegnazioni

La migrazione è per la casa già esistente e non cancella dati. Dopo aver aperto il progetto Supabase con l'account che ne è proprietario:

1. Apri **SQL Editor** e crea una nuova query.
2. Apri il file `MISSION_SOCIAL_FEATURES.sql` di questa cartella, copia tutto il contenuto e incollalo nella query.
3. Premi **Run** e attendi il messaggio di completamento.
4. Pubblica poi i file aggiornati dell'app (`app.js` e `styles.css`) nel repository collegato a Vercel, oppure carica `vercel-upload.zip` secondo la procedura già usata.

Le modifiche aggiungono le didascalie alle prove, le funzioni sicure per scambi e riassegnazioni, e il campo bonus alle missioni. Il bonus viene assegnato una volta sola insieme ai punti quando la prova della missione più pesante viene approvata.
