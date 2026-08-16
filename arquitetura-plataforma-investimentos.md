# Plataforma de Investimentos — Arquitetura (Spring Boot / Java 17)

Domínio: acompanhamento de investimentos em **ações da B3 (bolsa brasileira)**, **S&P 500** e **Bitcoin**, com portfólio, histórico de preços, alertas e relatórios.

---

## 1. Estilo de arquitetura

Recomendo começar como um **monólito modular** (não microsserviços de cara). Você aplica os mesmos conceitos (mensageria, CQRS, cache, async) dentro de um único deploy, com módulos bem separados por pacote. Isso reduz a complexidade operacional (não precisa orquestrar N serviços) e ainda assim te dá espaço pra extrair um módulo como microsserviço depois (ex: `market-data-ingestion` é o candidato mais natural, porque já é assíncrono e desacoplado por eventos).

```
com.seuprojeto.investimentos
├── auth            (usuários, JWT, roles)
├── asset           (catálogo de ativos: ações BR, S&P500, BTC)
├── marketdata       (ingestão de preços externos, async)
├── portfolio        (carteiras, transações, holdings)
├── alert            (alertas de preço)
├── reporting         (read-model CQRS, dashboards)
├── audit            (log de auditoria)
└── shared            (eventos, exceptions, utils)
```

### Camadas dentro de cada módulo
`controller → service → domain → repository`, com `client` separado para integrações externas (ex: `marketdata.client.B3Client`, `marketdata.client.CoinGeckoClient`).

---

## 2. Fontes de dados externas

| Mercado | Fonte sugerida | Observação |
|---|---|---|
| Ações B3 | brapi.dev, Alpha Vantage, ou scraping da B3 | brapi.dev é gratuita e simples pra começar |
| S&P 500 | Alpha Vantage, Yahoo Finance (via lib não-oficial) | Alpha Vantage tem free tier com rate limit baixo — bom motivo real pra você implementar o item 12 (rate limiting) |
| Bitcoin | CoinGecko API ou Binance API | CoinGecko não exige key para uso básico |

Essas integrações ficam isoladas no módulo `marketdata`, atrás de uma interface (`PriceProvider`), pra você trocar de fonte sem afetar o resto do sistema.

---

## 3. Tabelas do banco (PostgreSQL)

### `users`
| coluna | tipo |
|---|---|
| id | UUID PK |
| name | varchar |
| email | varchar unique |
| password_hash | varchar |
| role | varchar (USER, ADMIN) |
| created_at | timestamp |

### `assets`
| coluna | tipo |
|---|---|
| id | UUID PK |
| ticker | varchar (ex: PETR4, ^GSPC, BTC) |
| name | varchar |
| asset_type | varchar (STOCK_BR, STOCK_US, CRYPTO) |
| currency | varchar (BRL, USD) |
| exchange | varchar (B3, NASDAQ, N/A) |
| active | boolean |
| created_at | timestamp |

### `asset_prices` (série temporal)
| coluna | tipo |
|---|---|
| id | bigserial PK |
| asset_id | UUID FK → assets |
| price | numeric(18,8) |
| volume | numeric, nullable |
| captured_at | timestamp |

> Essa tabela cresce rápido. Vale indexar `(asset_id, captured_at)` e, mais pra frente, considerar particionamento por data ou TimescaleDB.

### `portfolios`
| coluna | tipo |
|---|---|
| id | UUID PK |
| user_id | UUID FK → users |
| name | varchar |
| created_at | timestamp |

### `transactions`
| coluna | tipo |
|---|---|
| id | UUID PK |
| portfolio_id | UUID FK |
| asset_id | UUID FK |
| type | varchar (BUY, SELL) |
| quantity | numeric(18,8) |
| unit_price | numeric(18,8) |
| total_value | numeric(18,2) |
| transaction_date | timestamp |
| created_at | timestamp |

### `holdings` (read-model, alimentado por eventos — CQRS)
| coluna | tipo |
|---|---|
| portfolio_id | UUID |
| asset_id | UUID |
| quantity | numeric(18,8) |
| avg_price | numeric(18,8) |
| current_value | numeric(18,2) |
| updated_at | timestamp |

PK composta `(portfolio_id, asset_id)`. Essa tabela nunca recebe escrita direta do usuário — só é atualizada por um consumidor que escuta `transaction.created` e `asset.price.updated`.

### `watchlist_items`
| coluna | tipo |
|---|---|
| id | UUID PK |
| user_id | UUID FK |
| asset_id | UUID FK |
| created_at | timestamp |

### `alerts`
| coluna | tipo |
|---|---|
| id | UUID PK |
| user_id | UUID FK |
| asset_id | UUID FK |
| condition | varchar (ABOVE, BELOW) |
| target_price | numeric(18,8) |
| status | varchar (ACTIVE, TRIGGERED, CANCELLED) |
| created_at | timestamp |
| triggered_at | timestamp, nullable |

### `audit_log`
| coluna | tipo |
|---|---|
| id | bigserial PK |
| entity_name | varchar |
| entity_id | UUID |
| action | varchar (CREATE, UPDATE, DELETE) |
| performed_by | UUID |
| payload_before | jsonb |
| payload_after | jsonb |
| performed_at | timestamp |

### `statement_imports` (upload de extrato de corretora — item 5)
| coluna | tipo |
|---|---|
| id | UUID PK |
| user_id | UUID FK |
| file_url | varchar (S3/minio) |
| status | varchar (PENDING, PROCESSING, DONE, FAILED) |
| created_at | timestamp |
| processed_at | timestamp, nullable |

---

## 4. Eventos assíncronos (mensageria)

Comece com RabbitMQ (mais simples de rodar localmente que Kafka; migre pra Kafka só se quiser explorar particionamento/replay de eventos).

- `asset.price.updated` → publicado pelo `marketdata` a cada coleta de preço → consumido por `reporting` (atualiza `holdings`) e `alert` (verifica se algum alerta deve disparar)
- `transaction.created` → publicado pelo `portfolio` → consumido por `reporting` (recalcula holdings) e `audit`
- `statement.import.uploaded` → publicado ao subir um extrato → consumido por um worker assíncrono que faz parsing e cria as `transactions`

---

## 5. Mapeando os 15 conceitos do seu documento pra este projeto

| # | Conceito | Onde entra aqui |
|---|---|---|
| 1 | Mensageria | Eventos acima (preço atualizado, transação criada) |
| 2 | Async pesado | Coleta periódica de preços (`@Scheduled` + `@Async`), parsing de extrato importado |
| 3 | CQRS | `holdings` como read-model, separado das `transactions` (write-model) |
| 4 | Cache | Redis para preço atual de cada ativo (TTL curto, ex: 30s-1min) e para dashboard do portfólio |
| 5 | Upload | Import de extrato de corretora (CSV/PDF) via S3/minio |
| 6 | Busca full-text | Buscar ativos por ticker/nome (Elasticsearch, ou `pg_trgm` no Postgres pra começar mais simples) |
| 7 | Auth | Spring Security + JWT, roles USER/ADMIN |
| 8 | API docs | springdoc-openapi |
| 9 | Migrations | Flyway |
| 10 | Observabilidade | Actuator + Micrometer, tracing na chamada às APIs externas (útil pra ver latência do CoinGecko/Alpha Vantage) |
| 11 | CI/CD | Dockerfile + GitHub Actions |
| 12 | Rate limiting | Protege seus próprios endpoints, mas também é a defesa contra estourar o limite das APIs externas (Alpha Vantage tem free tier bem restrito) |
| 13 | Auditing/soft delete | `audit_log` + soft delete em `transactions` |
| 14 | Data seeding | Popular `assets` com tickers populares (PETR4, VALE3, principais do S&P500, BTC) via `CommandLineRunner` no profile dev |
| 15 | Paginação/filtros | Histórico de transações, listagem de ativos por tipo/faixa de preço |

---

## 6. Ordem sugerida de implementação

1. Modelagem + `assets`/`users` + Flyway + seeding
2. Auth (JWT) + Swagger
3. CRUD de portfólio/transações + paginação/filtros
4. Integração com as 3 fontes externas (`marketdata`), com `@Async`
5. Cache (Redis) nos preços
6. Mensageria: publicar `transaction.created` e `asset.price.updated`
7. Read-model `holdings` (CQRS) alimentado pelos eventos
8. Alertas (consumidor de `asset.price.updated`)
9. Observabilidade (Actuator/Micrometer)
10. Auditing
11. Upload de extrato + parsing assíncrono
12. Busca full-text de ativos
13. Rate limiting
14. Dockerfile + CI/CD

Essa ordem prioriza ter algo funcional cedo (CRUD + auth) antes de entrar nas partes mais complexas (CQRS, mensageria).
