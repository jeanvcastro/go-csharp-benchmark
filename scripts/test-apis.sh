#!/bin/bash

echo "🧪 Testando APIs Go e C#..."

echo ""
echo "📊 Testando Go API (localhost:8080):"
echo "Health check:"
curl -s http://localhost:8080/health || echo "❌ Go health check failed"

echo ""
echo "Users endpoint:"
curl -s http://localhost:8080/api/v1/users?limit=5 || echo "❌ Go users endpoint failed"

echo ""
echo "📊 Testando C# API (localhost:8081):"
echo "Health check:"
curl -s http://localhost:8081/health || echo "❌ C# health check failed"

echo ""
echo "Users endpoint:"
curl -s http://localhost:8081/api/v1/users?limit=5 || echo "❌ C# users endpoint failed"

echo ""
echo "🔍 Verificando se as respostas são JSON válidas..."

# Test Go users endpoint
go_response=$(curl -s http://localhost:8080/api/v1/users?limit=1)
if echo "$go_response" | jq . > /dev/null 2>&1; then
    echo "✅ Go API retorna JSON válido"
else
    echo "❌ Go API não retorna JSON válido:"
    echo "$go_response"
fi

# Test C# users endpoint
csharp_response=$(curl -s http://localhost:8081/api/v1/users?limit=1)
if echo "$csharp_response" | jq . > /dev/null 2>&1; then
    echo "✅ C# API retorna JSON válido"
else
    echo "❌ C# API não retorna JSON válido:"
    echo "$csharp_response"
fi

echo ""
echo "✅ Teste das APIs concluído"