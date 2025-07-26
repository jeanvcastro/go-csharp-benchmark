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

setup_python_environment() {
    echo "🐍 Configurando ambiente Python..."
    
    # Check if Python is already configured (skip if working)
    if python3 -c "import pandas, matplotlib, seaborn" &> /dev/null; then
        echo "✅ Python já configurado com todas as dependências"
        return 0
    fi
    
    # Check if pyenv is available
    if command -v pyenv &> /dev/null; then
        echo "✅ pyenv encontrado"
        
        # Install Python version if not available
        PYTHON_VERSION=$(cat .python-version 2>/dev/null || echo "3.11.6")
        if ! pyenv versions --bare | grep -q "^${PYTHON_VERSION}$"; then
            echo "📦 Instalando Python ${PYTHON_VERSION}..."
            pyenv install ${PYTHON_VERSION}
        fi
        
        # Set local Python version
        pyenv local ${PYTHON_VERSION}
        echo "✅ Python ${PYTHON_VERSION} configurado"
    else
        echo "⚠️  pyenv não encontrado, usando Python do sistema"
        if ! command -v python3 &> /dev/null; then
            echo "❌ Python 3 não está instalado"
            echo "💡 Para configuração avançada Python, use: ./scripts/setup-python.sh"
            echo "Instale Python 3.11+ ou pyenv:"
            echo "  brew install pyenv python3  # macOS"
            echo "  apt install python3 python3-pip  # Ubuntu"
            exit 1
        fi
    fi
    
    # Install/upgrade pip
    python3 -m pip install --upgrade pip
    
    # Install requirements
    if [ -f "requirements.txt" ]; then
        echo "📦 Instalando dependências Python..."
        python3 -m pip install -r requirements.txt
        echo "✅ Dependências Python instaladas"
    else
        echo "⚠️  requirements.txt não encontrado"
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
    
    echo "🔍 Verificando aplicação C#..."
    csharp_ready=false
    for i in {1..30}; do
        if curl -s http://localhost:8081/health > /dev/null 2>&1; then
            echo "✅ Aplicação C# está pronta"
            csharp_ready=true
            break
        fi
        echo "    Aguardando C# app... (tentativa $i/30)"
        sleep 2
    done
    
    if [ "$go_ready" = false ]; then
        echo "⚠️  Aplicação Go não está respondendo, verifique logs: docker-compose logs go-app"
    fi
    
    if [ "$csharp_ready" = false ]; then
        echo "⚠️  Aplicação C# não está respondendo, verifique logs: docker-compose logs csharp-app"
    fi
}

verify_services() {
    echo "🔍 Verificando containers Docker..."
    
    containers=("benchmark_postgres" "benchmark_prometheus" "benchmark_grafana" "benchmark_go_app" "benchmark_csharp_app")
    
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
    echo "    • Go API:     http://localhost:8080 (/health, /metrics, /api/v1/users)"
    echo "    • C# API:     http://localhost:8081 (/health, /metrics, /api/v1/users)"
    echo "    • PostgreSQL: localhost:5432 (benchmark/benchmark_user/benchmark_pass)"
    echo "    • Prometheus: http://localhost:9090"
    echo "    • Grafana:    http://localhost:3000 (admin/admin123)"
    echo ""
    echo "🔧 Para verificar logs dos serviços:"
    echo "    docker-compose logs -f [go-app|csharp-app|postgres|prometheus|grafana]"
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
    setup_python_environment
    cleanup_existing
    start_infrastructure
    verify_services
    show_access_info
}

main "$@"