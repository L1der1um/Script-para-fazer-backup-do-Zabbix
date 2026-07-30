#!/bin/bash

# Cores para mensagens
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_splash() {
    clear
    echo -e "\e[31m"
    echo "███████╗ █████╗ ██████╗ ██████╗ ██╗██╗  ██╗"
    echo "╚══███╔╝██╔══██╗██╔══██╗██╔══██╗██║╚██╗██╔╝"
    echo "  ███╔╝ ███████║██████╔╝██████╔╝██║ ╚███╔╝ "
    echo " ███╔╝  ██╔══██║██╔══██╗██╔══██╗██║ ██╔██╗ "
    echo "███████╗██║  ██║██████╔╝██████╔╝██║██╔╝ ██╗"
    echo "╚══════╝╚═╝  ╚═╝╚═════╝╚═════╝ ╚═╝╚═╝  ╚═╝"
    echo -e "\e[0m"
    echo "========================================================"
    echo "                 BACKUP ZABBIX 7 LTS"
    echo "========================================================"
    echo ""
    sleep 2
}

show_splash

echo -e "${BLUE}========================================================${NC}"
echo -e "          ${YELLOW}🚀 Fórum Telecom${NC}"
echo -e "          ${YELLOW}📜 Script por Cristiano Figueiredo${NC}"
echo -e "${BLUE}========================================================${NC}"


BACKUP_DIR="/backup_zabbix"
DATE=$(date +%Y-%m-%d)
BACKUP_PATH="$BACKUP_DIR/bkp_$DATE"
# Pastas vitais do Zabbix a serem salvas
ZABBIX_DIRS="/etc/zabbix /usr/share/zabbix /usr/lib/zabbix /var/log/zabbix"

# Verifica se é root
if [ "$(id -u)" != "0" ]; then
    echo "❌ Este script deve ser executado como root."
    exit 1
fi

# Verifica dependências (removidos jq e curl)
for cmd in tar gzip mysqldump mysql; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ Erro: $cmd não encontrado. Instale primeiro."
        exit 1
    fi
done

# Cria diretório base
mkdir -p "$BACKUP_PATH" || {
    echo "❌ Falha ao criar diretório de backup"
    exit 1
}
chmod 777 "$BACKUP_PATH"

# Função de backup de banco de dados
backup_database() {
    local db_user=$1 db_pass=$2 db_name=$3 db_host=$4
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local file="$BACKUP_PATH/zabbix_db_${timestamp}.sql.gz"
    local min_size=50000  # Tamanho mínimo válido (50KB)

    echo -e "\n🔍 Iniciando backup do banco Zabbix..."

    # Verifica conexão com o banco antes do backup ocultando a senha
    if ! MYSQL_PWD="$db_pass" mysql -h "$db_host" -u "$db_user" -e "USE $db_name" 2>/dev/null; then
        echo "❌ ERRO: Não foi possível conectar ao banco Zabbix"
        echo "Verifique:"
        echo "1. Serviço MySQL/MariaDB está rodando"
        echo "2. Credenciais fornecidas estão corretas"
        echo "3. Usuário $db_user tem privilégios necessários"
        return 1
    fi

    # Detecta versão do MySQL/MariaDB para opções específicas
    local mysql_version=$(MYSQL_PWD="$db_pass" mysql -h "$db_host" -u "$db_user" -e "SELECT VERSION()" -s 2>/dev/null)
    local extra_opts=""

    if [[ "$mysql_version" == *"MariaDB"* ]]; then
        extra_opts="--column-statistics=0"
    elif [[ "$mysql_version" =~ 8\.0 ]]; then
        extra_opts="--column-statistics=0"
    fi

    echo "🔄 Gerando dump do banco Zabbix (pode demorar)..."

    # Comando de backup otimizado (Hot Backup)
    if ! MYSQL_PWD="$db_pass" mysqldump -h "$db_host" -u "$db_user" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --default-character-set=utf8mb4 \
        --no-tablespaces \
        $extra_opts \
        "$db_name" | gzip > "$file"; then
        echo "❌ ERRO: Falha durante o dump do banco Zabbix"
        rm -f "$file"
        return 1
    fi

    # Verifica se o backup tem tamanho válido
    local actual_size=$(wc -c < "$file" | awk '{print $1}')
    if [ "$actual_size" -lt "$min_size" ]; then
        echo "❌ ERRO: Backup do Zabbix parece inválido (tamanho: $actual_size bytes)"
        rm -f "$file"
        return 1
    fi

    echo "✅ Backup do Zabbix criado com sucesso: $file ($(du -h "$file" | cut -f1))"
    return 0
}

# --- Início da Execução Principal ---
echo -e "\n🔧 Backup Zabbix"
echo "📂 Diretório de backup: $BACKUP_PATH"

echo -e "\n🔵 Processando Zabbix..."
read -p "👉 Usuário do BD Zabbix: " ZABBIX_DB_USER
read -s -p "🔒 Senha do BD Zabbix: " ZABBIX_DB_PASS
echo ""

# Chama a função de backup do banco
backup_database "$ZABBIX_DB_USER" "$ZABBIX_DB_PASS" "zabbix" "localhost"

echo -e "\n📦 Compactando arquivos estruturais do Zabbix..."
if tar -czf "$BACKUP_PATH/zabbix_dirs_$DATE.tar.gz" $ZABBIX_DIRS 2>/dev/null; then
    echo "✅ Arquivos do Zabbix compactados"
else
    echo "⚠️  Erro ao compactar arquivos do Zabbix"
fi

# Resumo final
echo -e "\n📋 Resumo do backup:"
echo "================================="
du -sh "$BACKUP_PATH"/*
echo -e "\n✅ Backup concluído em: $BACKUP_PATH"
echo "================================="