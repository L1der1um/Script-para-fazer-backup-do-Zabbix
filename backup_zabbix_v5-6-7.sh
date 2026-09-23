#!/usr/bin/env bash
# ==============================================================================
# Script de Backup Automatizado - Zabbix 7.0, 6.0 e 5.0 LTS & MariaDB/MySQL
# Autor Original: Cristiano Figueiredo | Refatorado para Alta Confiabilidade
# Curso Zabbix e Grafana do Forum Telecom
# ==============================================================================

# Cores para mensagens
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
    echo "            BACKUP ZABBIX"
    echo "========================================================"
    echo ""
    sleep 1
}

show_splash

BACKUP_DIR="/backup_zabbix"
DATE=$(date +%Y-%m-%d)
BACKUP_PATH="$BACKUP_DIR/bkp_$DATE"
ZABBIX_DIRS="/etc/zabbix /usr/share/zabbix /usr/lib/zabbix /var/log/zabbix"

# 1. Verifica privilégios de root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}❌ Este script deve ser executado como root.${NC}" >&2
    exit 1
fi

# 2. Verifica dependências necessárias
for cmd in tar gzip mysqldump mysql; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}❌ Erro: Comando '$cmd' não encontrado. Instale-o primeiro.${NC}" >&2
        exit 1
    fi
done

# 3. Cria diretório base de backup com permissões seguras
mkdir -p "$BACKUP_PATH" || {
    echo -e "${RED}❌ Falha ao criar diretório $BACKUP_PATH${NC}" >&2
    exit 1
}
chmod 750 "$BACKUP_PATH"

# 4. Função de backup da base relacional
backup_database() {
    local db_user=$1 db_pass=$2 db_name=$3 db_host=$4
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local file="$BACKUP_PATH/zabbix_db_${timestamp}.sql.gz"
    local min_size=50000  # Tamanho mínimo esperado (~50KB)

    echo -e "\n🔍 Validando conectividade com o banco de dados..."

    if ! MYSQL_PWD="$db_pass" mysql -h "$db_host" -u "$db_user" -e "USE $db_name" 2>/dev/null; then
        echo -e "${RED}❌ ERRO: Não foi possível conectar ao banco '$db_name'.${NC}"
        echo "Verifique se o MariaDB está ativo e se o usuário/senha estão corretos."
        return 1
    fi

    # Detecção à prova de falhas: verifica se o CLIENTE mysqldump suporta a flag
    local extra_opts=""
    if mysqldump --help 2>&1 | grep -q "\-\-column-statistics"; then
        extra_opts="--column-statistics=0"
    fi

    echo -e "🔄 Gerando dump consistente do banco (pode demorar alguns instantes)..."

    # Ativa pipefail temporariamente para capturar falhas reais no mysqldump
    set -o pipefail
    local dump_err
    dump_err=$(mktemp)

    if ! MYSQL_PWD="$db_pass" mysqldump -h "$db_host" -u "$db_user" \
        --single-transaction \
        --quick \
        --routines \
        --triggers \
        --events \
        --default-character-set=utf8mb4 \
        $extra_opts \
        "$db_name" 2>"$dump_err" | gzip > "$file"; then
        
        echo -e "${RED}❌ ERRO: Falha durante a execução do mysqldump:${NC}"
        cat "$dump_err"
        rm -f "$file" "$dump_err"
        set +o pipefail
        return 1
    fi
    set +o pipefail
    rm -f "$dump_err"

    # Validação de integridade volumétrica
    local actual_size=$(wc -c < "$file" | awk '{print $1}')
    if [ "$actual_size" -lt "$min_size" ]; then
        echo -e "${RED}❌ ERRO: O arquivo gerado é muito pequeno ($actual_size bytes). O dump pode estar corrompido.${NC}"
        rm -f "$file"
        return 1
    fi

    echo -e "${GREEN}✅ Backup do banco gerado com sucesso:${NC} $file ($(du -h "$file" | cut -f1))"
    return 0
}

# --- EXECUÇÃO PRINCIPAL ---
echo -e "\n🔧 ${BLUE}Iniciando Rotina de Backup do Zabbix${NC}"
echo -e "📂 Diretório de destino: ${YELLOW}$BACKUP_PATH${NC}\n"

# Solicita credenciais com valores padrão práticos
read -rp "👉 Usuário do BD Zabbix [Padrão: zabbix]: " ZABBIX_DB_USER
ZABBIX_DB_USER=${ZABBIX_DB_USER:-zabbix}

read -rsp "🔒 Senha do BD Zabbix [Padrão: zabbix]: " ZABBIX_DB_PASS
echo ""
ZABBIX_DB_PASS=${ZABBIX_DB_PASS:-zabbix}

# Executa dump do banco
if ! backup_database "$ZABBIX_DB_USER" "$ZABBIX_DB_PASS" "zabbix" "localhost"; then
    echo -e "\n${RED}⚠️  Abortando: O backup do banco de dados não foi concluído.${NC}"
    exit 1
fi

# Compacta diretórios de configuração e assets
echo -e "\n📦 Compactando diretórios de configuração e web do Zabbix..."
TAR_FILE="$BACKUP_PATH/zabbix_dirs_$DATE.tar.gz"

# Compacta apenas os diretórios que realmente existem no disco
EXISTING_DIRS=""
for d in $ZABBIX_DIRS; do
    [ -d "$d" ] && EXISTING_DIRS="$EXISTING_DIRS $d"
done

if tar -czf "$TAR_FILE" $EXISTING_DIRS 2>/dev/null; then
    echo -e "${GREEN}✅ Arquivos estruturais compactados com sucesso:${NC} $(du -h "$TAR_FILE" | cut -f1)"
else
    echo -e "${YELLOW}⚠️  Aviso: Alguns arquivos secundários não puderam ser arquivados.${NC}"
fi

# Resumo final
echo -e "\n📋 ${BLUE}Resumo dos Artefatos de Backup:${NC}"
echo "=========================================================="
du -sh "$BACKUP_PATH"/*
echo "=========================================================="
echo -e "${GREEN}✅ Rotina de backup finalizada com sucesso em: $BACKUP_PATH${NC}\n"
