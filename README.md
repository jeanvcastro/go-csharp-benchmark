# 🚀 Language Performance Benchmark

Benchmark completo comparando performance entre **Go** e **C#** em cenários reais de produção, medindo latência, throughput, consumo de recursos e eficiência de acesso a dados. A aplicação C# é testada com **Entity Framework** e **Dapper** para análise comparativa de ORMs.

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

1. **API Load Test** - Teste de carga com 1000 req/s
   - 60% operações de leitura
   - 30% operações de escrita
   - 10% operações de exclusão

2. **Database Stress Test** - Teste de estresse do banco
   - 50 conexões concorrentes
   - Operações CRUD intensivas
   - Análise de pool de conexões

3. **Memory Pressure Test** - Teste de pressão de memória
   - Payloads grandes
   - Stress do Garbage Collector
   - Análise de vazamentos de memória

### 🏆 Resultados dos Últimos Benchmarks

| Aplicação | API Load (ms) | DB Stress (ms) | Memory Test (ms) | Erro Rate |
|-----------|---------------|----------------|------------------|-----------|
| **Go** | 308.90 | 1.66 | 2.34 | 0.00% - 18.66% |
| **C# Entity Framework** | 384.82 | 4.79 | 3.76 | 0.00% - 5.95% |
| **C# Dapper** | 349.06 | 4.98 | 3.68 | 0.00% - 6.39% |

*📈 Relatório completo disponível em `results/*/reports/benchmark_comparison_report.md`*

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

