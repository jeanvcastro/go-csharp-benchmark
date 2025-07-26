#!/bin/bash

set -e

echo "🚀 Iniciando setup do ambiente de benchmark Go vs C#"

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker não está instalado"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose não está instalado"
        exit 1
    fi
}

build_analysis_image() {
    echo "🐍 Preparando imagem Docker para análise..."
    
    if docker images | grep -q "benchmark_analysis"; then
        echo "✅ Imagem de análise já existe"
    else
        echo "📦 Buildando imagem de análise..."
        docker build -t benchmark_analysis scripts/analysis/
        echo "✅ Imagem de análise criada"
    fi
}

cleanup_existing() {
    echo "🧹 Parando containers do projeto..."
    docker-compose down -v 2>/dev/null || true
}

start_infrastructure() {
    echo "🐳 Iniciando todos os serviços..."
    docker-compose up -d --build
    
    echo "⏳ Aguardando PostgreSQL ficar pronto..."
    timeout=60
    while ! docker exec benchmark_postgres pg_isready -U benchmark_user -d benchmark > /dev/null 2>&1; do
        if [ $timeout -le 0 ]; then
            echo "❌ PostgreSQL não ficou pronto a tempo"
            exit 1
        fi
        echo "    Aguardando PostgreSQL... ($timeout segundos restantes)"
        sleep 2
        timeout=$((timeout-2))
    done
    
    echo "✅ PostgreSQL está pronto"
    
    echo "⏳ Aguardando aplicações ficarem prontas..."
    sleep 10  # Dar tempo para as apps buildarem e iniciarem
    
    # Verificar se as aplicações estão respondendo
    echo "🔍 Verificando aplicação Go..."
    go_ready=false
    for i in {1..30}; do
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            echo "✅ Aplicação Go está pronta"
            go_ready=true
            break
        fi
        echo "    Aguardando Go app... (tentativa $i/30)"
        sleep 2
    done
    
    echo "🔍 Verificando aplicação C# EF..."
    csharp_ef_ready=false
    for i in {1..30}; do
        if curl -s http://localhost:8081/health > /dev/null 2>&1; then
            echo "✅ Aplicação C# EF está pronta"
            csharp_ef_ready=true
            break
        fi
        echo "    Aguardando C# EF app... (tentativa $i/30)"
        sleep 2
    done
    
    echo "🔍 Verificando aplicação C# Dapper..."
    csharp_dapper_ready=false
    for i in {1..30}; do
        if curl -s http://localhost:8082/health > /dev/null 2>&1; then
            echo "✅ Aplicação C# Dapper está pronta"
            csharp_dapper_ready=true
            break
        fi
        echo "    Aguardando C# Dapper app... (tentativa $i/30)"
        sleep 2
    done
    
    if [ "$go_ready" = false ]; then
        echo "⚠️  Aplicação Go não está respondendo, verifique logs: docker-compose logs go-app"
    fi
    
    if [ "$csharp_ef_ready" = false ]; then
        echo "⚠️  Aplicação C# EF não está respondendo, verifique logs: docker-compose logs csharp-ef-app"
    fi
    
    if [ "$csharp_dapper_ready" = false ]; then
        echo "⚠️  Aplicação C# Dapper não está respondendo, verifique logs: docker-compose logs csharp-dapper-app"
    fi
}

verify_services() {
    echo "🔍 Verificando containers Docker..."
    
    containers=("benchmark_postgres" "benchmark_prometheus" "benchmark_grafana" "benchmark_go_app" "benchmark_csharp_ef_app" "benchmark_csharp_dapper_app")
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "$container"; then
            echo "    ✅ $container está rodando"
        else
            echo "    ❌ $container não está rodando"
        fi
    done
}

show_access_info() {
    echo ""
    echo "🎉 Setup concluído com sucesso!"
    echo ""
    echo "📊 Serviços disponíveis:"
    echo "    • Go API:         http://localhost:8080 (/health, /metrics, /api/v1/users)"
    echo "    • C# Dapper API:  http://localhost:8082 (/health, /metrics, /api/v1/users)"
    echo "    • C# EF API:      http://localhost:8081 (/health, /metrics, /api/v1/users)"
    echo "    • PostgreSQL: localhost:5432 (benchmark/benchmark_user/benchmark_pass)"
    echo "    • Prometheus: http://localhost:9090"
    echo "    • Grafana:    http://localhost:3000 (admin/admin123)"
    echo ""
    echo "🔧 Para verificar logs dos serviços:"
    echo "    docker-compose logs -f [go-app|csharp-ef-app|csharp-dapper-app|postgres|prometheus|grafana]"
    echo ""
    echo "🧪 Para executar benchmarks:"
    echo "    ./scripts/run-benchmarks.sh"
    echo ""
    echo "🛑 Para parar todos os serviços:"
    echo "    docker-compose down"
}

main() {
    echo "🚀 Inicializando ambiente de benchmark Go vs C#"
    echo "Started at: $(date)"
    echo ""
    
    check_docker
    build_analysis_image
    cleanup_existing
    start_infrastructure
    verify_services
    show_access_info
}

main "$@"