# Tema 2 - Implementarea CUDA a algoritmului de consens Proof of Work din cadrul Bitcoin #

## Implementare ##
### Explicatia implementarii ###
Pentru implementarea pe GPU, am început prin a aloca memorie pentru variabilele necesare:

->d_block_content - blocul de date care va fi minat
->d_block_hash - hash-ul blocului
->d_difficulty - dificultatea, reprezentând nivelul de complexitate necesar pentru a găsi un nonce valid care să îndeplinească anumite condiții de hashing
->d_found_nonce - nonce-ul găsit, adică numărul întreg care, împreună cu datele blocului, să genereze un hash care să îndeplinească condițiile de hashing
Am copiat datele de la gazdă la dispozitiv și am apelat kernel-ul findNonce, care caută nonce-ul pe GPU.

Am apelat funcția findNonce pentru a găsi blocul cu nonce-ul valid și am copiat rezultatul înapoi pe gazdă pentru a fi afișat.

#### Functia findNonce: ####
Apelarea functiei:
```findNonce<<<MAX_NONCE/THREADS_PER_BLOCK, THREADS_PER_BLOCK>>>(d_block_content, d_difficulty, d_found_nonce, d_found_block_hash);```
MAX_NONCE/THREADS_PER_BLOCK - numărul total de blocuri de fire de execuție (thread blocks) care vor fi pornite pentru a rula kernelul
MAX_NONCE - numărul maxim de nonce-uri care vor fi încercate
THREADS_PER_BLOCK - numărul de fire de execuție din fiecare bloc

#### Functionalitate: ####
Se calculează nonce-ul pentru fiecare fir de execuție pe baza blocului și a thread-urilor CUDA, asigurându-se că fiecare fir de execuție va încerca un nonce diferit. Pentru a evita conflictele de acces la date, conținutul blocului este copiat într-un bloc local, astfel încât toate firele de execuție să aibă acces la aceeași copie și să producă rezultate consistente. Înainte de a începe căutarea, se verifică dacă un alt fir de execuție a găsit deja un nonce valid sau dacă nonce-ul curent depășește limita maximă stabilită. În caz afirmativ, căutarea este oprită. Dacă niciuna dintre aceste condiții nu este îndeplinită, nonce-ul curent este transformat într-un șir de caractere și concatenat la datele blocului. Apoi, se calculează hash-ul acestui nou bloc și se verifică dacă acesta îndeplinește condițiile de hashing folosind functia ```compare_hashes``` si operația atomică atomicExch, care garantează că doar un fir de execuție poate scrie în variabila de nonce găsit și în hash-ul blocului.

### Ideea implementarii ### 
Ideea din spatele implementării se bazează pe conceptul de blockchain, o structură de date descentralizată care funcționează prin construirea unui lanț de blocuri folosind un proces de criptare și verificare numit hashing. Am pornit de la un bloc de date comun pentru toate firele de execuție care vor lucra, dar am creat blocuri locale pentru a evita conflictele de acces și pentru a asigura că fiecare fir de execuție lucrează cu date independente, prevenind astfel generarea de rezultate invalide. Am continuat să calculăm hash-ul blocurilor până când am găsit un nonce valid. Un nonce valid este definit de dificultatea specificată, care reprezintă numărul de zerouri pe care trebuie să le aibă hash-ul blocului pentru a fi considerat valid. La final, am afișat blocul și nonce-ul găsit, eliberând în același timp memoria alocată pe dispozitiv

Resurse folosite:
- cpu_miner - in implementarea mea, am plecat de la algoritmul deja implementat pe CPU si l-am adaptat la lucrul pe GPU, folosind thread-urile

## Evaluarea performanței ##
După câteva rulări, am observat că timpul de execuție pe GPU este mai scăzut decât pe CPU, datorită numărului mai mare de nuclee pe GPU, care poate procesa mai multe thread-uri simultan, accelerând calculul. În plus, am constatat că timpul de execuție pe GPU scade pe măsură ce dificultatea crește, deoarece numărul de zerouri necesare pentru a găsi un nonce valid devine mai mic, ceea ce conduce la o viteză mai mare de calcul. În teste locale, timpul estimat pentru algoritmul pe GPU a fost de aproximativ 0.28 secunde, în timp ce pe CPU a fost de 1.00 secunde, pentru un test de dificultate 5. Aceasta indică o îmbunătățire semnificativă a performanței, cu aproximativ 3.5 ori, utilizând GPU-ul pentru acest tip de calcul.


