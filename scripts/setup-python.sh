#!/bin/bash

set -e

echo "🐍 Configurando ambiente Python para análise de benchmarks"

check_pyenv() {
    if command -v pyenv &> /dev/null; then
        echo "✅ pyenv encontrado: $(pyenv --version)"
        return 0
    else
        echo "⚠️  pyenv não encontrado"
        return 1
    fi
}

install_pyenv() {
    echo "📦 Instalando pyenv..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install pyenv
        else
            echo "❌ Homebrew não encontrado. Instale manualmente:"
            echo "https://github.com/pyenv/pyenv#installation"
            exit 1
        fi
    elif [[ -f /etc/debian_version ]]; then
        # Ubuntu/Debian
        curl https://pyenv.run | bash
        echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
        echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
        echo 'eval "$(pyenv init -)"' >> ~/.bashrc
        source ~/.bashrc
    else
        echo "❌ OS não suportado para instalação automática do pyenv"
        echo "Instale manualmente: https://github.com/pyenv/pyenv#installation"
        exit 1
    fi
}

setup_python_version() {
    local python_version=${1:-"3.11.6"}
    
    echo "🔧 Configurando Python ${python_version}..."
    
    # Install Python version if not available
    if ! pyenv versions --bare | grep -q "^${python_version}$"; then
        echo "📦 Instalando Python ${python_version}..."
        pyenv install ${python_version}
    else
        echo "✅ Python ${python_version} já está instalado"
    fi
    
    # Set local version
    pyenv local ${python_version}
    echo "✅ Python ${python_version} configurado para este projeto"
}

install_requirements() {
    echo "📦 Instalando dependências Python..."
    
    # Upgrade pip
    python -m pip install --upgrade pip
    
    # Install requirements
    if [ -f "requirements.txt" ]; then
        python -m pip install -r requirements.txt
        echo "✅ Dependências instaladas com sucesso"
    else
        echo "❌ requirements.txt não encontrado"
        exit 1
    fi
}

verify_installation() {
    echo "🔍 Verificando instalação..."
    
    echo "Python version: $(python --version)"
    echo "Pip version: $(python -m pip --version)"
    
    # Test import of key packages
    python -c "import pandas, matplotlib, seaborn; print('✅ Todas as dependências importadas com sucesso')" || {
        echo "❌ Erro ao importar dependências"
        exit 1
    }
}

main() {
    local python_version=$(cat .python-version 2>/dev/null || echo "3.11.6")
    
    echo "Configurando Python ${python_version} para análise de benchmarks"
    echo ""
    
    # Check if pyenv is available, install if not
    if ! check_pyenv; then
        echo "🤔 Deseja instalar pyenv automaticamente? [y/N]"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            install_pyenv
        else
            echo "❌ pyenv é necessário para gerenciar versões Python"
            echo "Instale manualmente: https://github.com/pyenv/pyenv#installation"
            exit 1
        fi
    fi
    
    setup_python_version "$python_version"
    install_requirements
    verify_installation
    
    echo ""
    echo "🎉 Ambiente Python configurado com sucesso!"
    echo ""
    echo "📋 Para ativar o ambiente em novos terminais:"
    echo "   cd $(pwd)"
    echo "   pyenv local ${python_version}"
    echo ""
    echo "🚀 Agora você pode executar:"
    echo "   ./scripts/run-benchmarks.sh"
}

main "$@"