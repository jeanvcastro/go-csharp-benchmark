# 🚀 Language Performance Benchmark

Benchmark completo comparando performance entre **Go** e **C#** em cenários reais de produção, medindo latência, throughput, consumo de recursos e eficiência de acesso a dados. A aplicação C# é testada com **Entity Framework** e **Dapper** (micro-ORM) para análise comparativa de ORMs.

## 🏗️ Arquitetura

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   Go App        │  │ C# EF App       │  │ C# Dapper App   │
│   Port: 8080    │  │ Port: 8081      │  │ Port: 8082      │
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │                     │                     │
         └─────────────────────┼─────────────────────┘
                               │
         ┌─────────────────────▼─────────────────────┐
         │           PostgreSQL Database             │
         │              Port: 5432                   │
         └───────────────────────────────────────────┘
                               │
         ┌─────────────────────▼─────────────────────┐
         │    Monitoring Stack (Prometheus/Grafana) │
         │         Ports: 9090/3000                  │
         └───────────────────────────────────────────┘
```

## 🎯 Testes de Performance

### 📊 Cenários de Benchmark

1. **API Load Test** - Teste de carga progressiva (7min)
   - Ramp up: 1min → 100 VUs
   - Sustentado: 5min → 1000 VUs (distribuído entre 3 apps)
   - Ramp down: 1min → 0 VUs
   - Operações: 70% leitura, 30% escrita com criação de orders
   - Threshold: p95 < 500ms, erro < 5%

2. **Database Stress Test** - Estresse intensivo de BD (10min)
   - 50 conexões concorrentes constantes
   - 40% operações de leitura complexas com JOINs
   - 30% transações de escrita (usuário + múltiplos pedidos)
   - 15% operações em lote (batch)
   - 15% estresse do pool de conexões
   - Threshold: p95 < 1s, erro < 10%

3. **Memory Pressure Test** - Pressão de memória e GC (14min)
   - Ramp progressivo: 1 → 10 → 25 → 50 VUs
   - 30% payloads grandes (usuários com dados extensos)
   - 30% alocação/desalocação rápida (stress do GC)
   - 20% consultas com resultados grandes (100+ registros)
   - 20% operações em lote com dados volumosos
   - Threshold: p95 < 2s, erro < 15%

## 🚦 Quick Start

### Pré-requisitos

- Docker & Docker Compose
- k6 (ferramenta de teste de carga)

### 🔧 Setup Inicial

```bash
# Clone o repositório
git clone <repository-url>
cd language-benchmark

# Configure o ambiente (já inicia os serviços e testa as APIs)
./scripts/setup.sh
```

### 🏃‍♂️ Executando os Benchmarks

```bash
# Execute todos os testes de benchmark
./scripts/run-benchmarks.sh

# Ou execute testes individuais
k6 run ./k6-scripts/api-load-test.js
k6 run ./k6-scripts/database-stress-test.js
k6 run ./k6-scripts/memory-pressure-test.js
```

## 📁 Estrutura do Projeto

```
language-benchmark/
├── 🐹 go-app/                    # Aplicação Go
│   ├── cmd/main.go              # Entry point
│   ├── internal/                # Lógica interna
│   └── Dockerfile
├── 🔷 csharp-ef-app/            # C# com Entity Framework
│   ├── src/                     # Código fonte
│   ├── PerformanceBenchmark.sln
│   └── Dockerfile
├── 🔶 csharp-dapper-app/        # C# com Dapper
│   ├── src/                     # Código fonte
│   ├── PerformanceBenchmark.sln
│   └── Dockerfile
├── 🗄️ database/                 # Scripts SQL
│   ├── init.sql                 # Estrutura inicial
│   └── seed-data.sql           # Dados de teste
├── 📊 k6-scripts/               # Scripts de teste
│   ├── api-load-test.js
│   ├── database-stress-test.js
│   └── memory-pressure-test.js
├── 📈 monitoring/               # Configuração de monitoramento
│   ├── prometheus.yml
│   └── grafana-dashboard.json
├── 🛠️ scripts/                  # Scripts utilitários
│   ├── run-benchmarks.sh       # Executor principal
│   ├── collect-metrics.sh      # Coleta métricas
│   └── analysis/               # Análise de resultados
└── 📋 results/                  # Resultados dos testes
```

## 🔍 Análise e Monitoramento

### 📊 Dashboards

- **Grafana**: http://localhost:3000 (admin/admin123)
- **Prometheus**: http://localhost:9090
- **APIs**:
  - Go: http://localhost:8080
  - C# EF: http://localhost:8081
  - C# Dapper: http://localhost:8082

### 📈 Métricas Coletadas

- **Latência**: p50, p95, p99
- **Throughput**: RPS (Requests Per Second)
- **Recursos**: CPU, Memória, I/O
- **Database**: Pool de conexões, query time
- **Aplicação**: GC time, heap usage

## 🛠️ Desenvolvimento

### Adicionando Novos Testes

1. Crie um novo script k6 em `k6-scripts/`
2. Adicione chamada no `run-benchmarks.sh`
3. Configure coleta de métricas específicas

### Modificando Aplicações

Cada aplicação expõe as mesmas rotas:
- `GET /users` - Lista usuários
- `POST /users` - Cria usuário
- `GET /users/{id}` - Busca usuário
- `DELETE /users/{id}` - Remove usuário
- `GET /orders` - Lista pedidos
- `POST /orders` - Cria pedido
- `GET /health` - Health check
- `GET /metrics` - Métricas Prometheus

## 🎯 Interpretando Resultados

### 🥇 Vencedores por Categoria

- **Latência Baixa**: Go consistently wins
- **Stability**: C# applications (lower error rates)
- **Memory Efficiency**: Go (menor uso de memória)
- **Database Performance**: Go (especialmente reads)

---

**Feito com ❤️ e vibecoding 🤖**

