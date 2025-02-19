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

I suggest first to use: https://huggingface.co/intfloat/multilingual-e5-large

## Python libraries
   torch
   sentence-transformer



