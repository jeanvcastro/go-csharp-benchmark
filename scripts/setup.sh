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

cleanup_existing() {
    echo "🧹 Parando containers do projeto..."
    docker-compose down -v 2>/dev/null || true
}

start_infrastructure() {
    echo "🐳 Iniciando serviços de infraestrutura..."
    docker-compose up -d postgres prometheus grafana
    
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
}

verify_services() {
    echo "🔍 Verificando serviços..."
    
    services=("benchmark_postgres:5432" "benchmark_prometheus:9090" "benchmark_grafana:3000")
    
    for service in "${services[@]}"; do
        container=${service%%:*}
        port=${service##*:}
        
        if docker ps --format "table {{.Names}}" | grep -q "$container"; then
            echo "    ✅ $container está rodando"
        else
            echo "    ❌ $container não está rodando"
            exit 1
        fi
    done
}

show_access_info() {
    echo ""
    echo "🎉 Setup concluído com sucesso!"
    echo ""
    echo "📊 Serviços disponíveis:"
    echo "    • PostgreSQL: localhost:5432 (benchmark/benchmark_user/benchmark_pass)"
    echo "    • Prometheus: http://localhost:9090"
    echo "    • Grafana:    http://localhost:3000 (admin/admin123)"
    echo ""
    echo "🔧 Para verificar logs dos serviços:"
    echo "    docker-compose logs -f [postgres|prometheus|grafana]"
    echo ""
    echo "🛑 Para parar todos os serviços:"
    echo "    docker-compose down"
}

main() {
    check_docker
    cleanup_existing
    start_infrastructure
    verify_services
    show_access_info
}

main "$@"