## Repo
https://github.com/pgvector/pgvector

## Instalation
```bash
sudo apt install postgresql-17-pgvector
```
It looks like is already in our docker image

## Adding to the database
```
CREATE EXTENSION vector;
```

## Embeddings
1. install python lib sentence_transformers
   ```bash
   pip install sentence-transformers
   ```
2. load model in python
   ```bash
   model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
   ```
3. download model to use it offline
  ```bash
  model.save("my_model/")
  # no You can load it from disk
  model = SentenceTransformer("my_model/")
  ```
4. Collect embeddeds: write python HAF applications which
    ```
   1. takes posts and push it to the model tomake embedd from it
   2. transform python form embed to SQL veectors
   3. push verctors to embeedds table
   ```
5. Search
   ```bash
   1. create indexes
   2. search with select
   ```
## Mozliwe modele do wykorzystania

| **Model** | **Wymiary** | **Języki** | **Zalety** | **Wady** | **Licencja** |
|-----------|------------|------------|------------|----------|--------------|
| `intfloat/multilingual-e5-large` | 1024 | 100+ | Świetny do wyszukiwania semantycznego i RAG | Duży rozmiar | Apache 2.0 |
| `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` | 384 | 50+ | Lekki, szybki, dobry do krótkich tekstów | Mniejsza dokładność | Apache 2.0 |
| `LaBSE (Language-agnostic BERT Sentence Embeddings)` | 768 | 100+ | Bardzo dokładny dla wielu języków | Wolniejszy | Apache 2.0 |
| `facebook/laser2` | 1024 | 100+ | Bardzo dobry dla długich dokumentów | Duży model | CC BY-NC 4.0 |
| `text-embedding-ada-002` (OpenAI) | 1536 | 100+ | Wysoka jakość embeddingów | API płatne | OpenAI API Terms of Use |

I suggest first to use: https://huggingface.co/intfloat/multilingual-e5-large, but it only supports 512 tokens
`facebook/laser2` 12000 tokenow, ale nie wyglada na popularny, i jest stary
https://github.com/timescale/pgai/ fajne 

## Python libraries
   1. **pgai** wszystko jest zrobione, tylko mało kontroli dla nas
      - TimescaleDB, zapewne chodzi o [pgvectorscale](https://github.com/timescale/pgvectorscale/) (fork pgvector) ale czy tylko ?
        pgvector scale twierdzi że pgvector nie radzi sobie z duzą iloscią danych, pgvectorscale instaluje też pgvector
      - TimescaleDb Community license: można używać o ile nie pobiera się pieniędzy za servisów
      - Wygląda na to ze mała kontrola nad tym co się dzieje, poprostu jestrujemy tablice i mówimy która kolumna ma podlegać
        wektoryzacji i metode chunkowaniam uruchami się process w tele który dokonuje vektoryzacji oraz sa troggery które
        regują na pojawienie się nowych wersji.
      - Nie dokońća wiadomo które featurs z TisescaleDb sa uzywane, jeśli hypertables to updaty mogą powodować problemy
      - Możliwe że nie bedzie moglo dzialać efektywnie w massive syncu, tylko trzeba będzie wypełnić tablice postów a potemją przekazać do vektoryzacji.
        Obawiam się że tak masowe inserty jak my robimy zabiją mechanizm śledzenia modyfikacji tabeli źródłowej. A moze nawet nie można modyfikowac gdy wektoryzacja się wykonuje
        trzeba to sprawdzić.
      - wspiera komercyjne model z API (wymaga kluczy do nich) oraz Ollama, ale to wszystko to komunikacja po API, zapewne
        dla performance nie ma to znaczenia ale bowiem komunikacja bedzie znikomym wysiłkiem w porównaniu do generowania embeddings
      - jeśli ollama to dla nas najlepsze modele: BGE-M3 lub starszy BGE-Large (oba 8192 tokeny i wektory 1024), multi języczne 100+
   2. **sentence-transformer**  specjalizowna do embeddings, wszystkie modele huggingface (BGE3-M3 też), używa ich bezpośrednio
        bez stawiania ollamy i wołania API. Trzeba by napisac program w pythonie ktory prztwarza zebrane post i wrzuca pgvectorscale
   3. **pyTorch** jest zbyt ogólny, dla wyszukiwarki wystarczy wyspecjalizowany sentence-transformer, który i tag go używa
   4. [laser](https://github.com/facebookresearch/LASER) -> całkowicie inny interfejs, nie wygląda na popularny

### Space126'738'273 -> number of posts in hive
posts are writen in different languages (ofc. english is a leader)
vector of 1024 float8 gives 1'038'239'932'416B > 1TB
HNSW ~= 3TB
IVFFLat ~= 200GB


### jade z donstalowaniem pgai do hiveminda
1. instalacja 
    git clone https://github.com/timescale/pgai.git --branch extension-0.8.0 
    cd pgai sudo python3 -m pip install --upgrade pip
    sudo python3 -m pip install --upgrade pip
    sudo projects/extension/build.py install
    sudo apt update
    sudo apt install postgresql-plpython3-17

2. w bazie danych: CREATE EXTENSION IF NOT EXISTS ai CASCADE;
3. wskazanie gdzie nalezy pytac ollame:
   ```bash
    INSERT INTO vectorized_posts (id, embedding)
    SELECT
    posts.id,
    ai.ollama_embed('bge-m3:latest', posts.body, host => 'http://192.168.6.17:11434')
    FROM (
    SELECT hp.id, hpd.body
    FROM hivemind_app.hive_posts as hp
    JOIN hivemind_app.hive_post_data as hpd ON hpd.id = hp.id
    WHERE hp.root_id=hp.parent_id LIMIT 1000
    ) AS posts;
   ```
4. vectorscale, nie jest czescia pgai, trzeba instalowac oddzielnie
   - Najpierw rust jako haf_admin
   ```bash
   git clone https://github.com/timescale/pgvectorscale.git
   cd pgvectorscale
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   sudo su # potrzebny by kopiowac do extension postgresa
   . /home/haf_admin/.cargo/env
    cargo install --locked cargo-pgrx --version $(cargo metadata --format-version 1 | jq -r '.packages[] | select(.name == "pgrx") | .version')
    cargo pgrx init --pg17 pg_config
    cargo pgrx install --release
i   ```


