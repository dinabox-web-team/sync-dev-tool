#!/usr/bin/env bash

# ===============================================
# Script de Sincronização SSH com Monitoramento
# ===============================================

# ===============================================
# Variáveis de Configuração (serão carregadas do .sync-config.ini ou flags)
# ===============================================

# Configurações do servidor remoto
HOST=""
REMOTE_PATH=""
USER=""
GROUP=""
SSH_KEY=""
CHMOD_DIRS="775"
CHMOD_FILES="664"
CHMOD_DIRS_EXIT="775"
CHMOD_FILES_EXIT="664"

# Diretório local a ser sincronizado (padrão: diretório atual onde o script é executado)
LOCAL_PATH="$(pwd)"

# Arquivos e diretórios a ignorar
IGNORE_FILES=()

# Arquivo de configuração padrão
CONFIG_INI=".sync-config.ini"

# Configurações de log
LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/sync.log"
DEBOUNCE_TIME=2  # Tempo em segundos para aguardar antes de sincronizar

# Arquivo de estado de sincronização
CONFIG_FILE="$HOME/.server-sync.inf"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ===============================================
# Funções auxiliares
# ===============================================

# Função para criar template do arquivo .sync-config.ini
create_config_template() {
    local config_file="${1:-.sync-config.ini}"
    
    if [ -f "$config_file" ]; then
        print_colored "$YELLOW" "⚠️  Arquivo $config_file já existe!"
        read -p "Deseja sobrescrever? (s/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            print_colored "$BLUE" "✅ Operação cancelada."
            return 0
        fi
    fi
    
    cat > "$config_file" << 'EOF'
# ===============================================
# Arquivo de Configuração do sync-dev
# ===============================================
# Este arquivo define as configurações para sincronização SSH
# Formato: CHAVE=valor (sem espaços ao redor do =)

# ============ OBRIGATÓRIAS ============

# Host do servidor remoto (ex: server.example.com)
HOST=

# Caminho completo no servidor remoto onde os arquivos serão sincronizados
REMOTE_PATH=

# Usuário SSH para conexão
USER=

# Grupo para aplicar nos arquivos remotos
GROUP=

# Caminho completo para a chave SSH privada
SSH_KEY=

# ============ OPCIONAIS ============

# Diretório local (padrão: diretório atual)
# LOCAL_PATH=

# Permissões para diretórios no servidor remoto (padrão: 775)
CHMOD_DIRS=775

# Permissões para arquivos no servidor remoto (padrão: 664)
CHMOD_FILES=664

# Permissões ao sair - diretórios (padrão: 775)
CHMOD_DIRS_EXIT=775

# Permissões ao sair - arquivos (padrão: 664)
CHMOD_FILES_EXIT=664

# Tempo de debounce em segundos para sincronização automática (padrão: 2)
DEBOUNCE_TIME=2

# Arquivos e diretórios a ignorar (separados por vírgula)
# Exemplo: .git,node_modules,dist,*.log,vendor
IGNORE_FILES=.git,node_modules,dist,*.log,vendor,tmp,composer.lock,ssh_key,.gitignore,.DS_Store,logs
EOF

    chmod 600 "$config_file"
    print_colored "$GREEN" "✅ Arquivo de configuração criado: $config_file"
    print_colored "$YELLOW" "\n📝 Próximos passos:"
    print_colored "$YELLOW" "   1. Edite o arquivo $config_file"
    print_colored "$YELLOW" "   2. Preencha as configurações obrigatórias (HOST, REMOTE_PATH, USER, GROUP, SSH_KEY)"
    print_colored "$YELLOW" "   3. Execute: sync-dev para sincronizar"
    print_colored "$YELLOW" "   4. Execute: sync-dev --watch para monitoramento contínuo\n"
}

# Função para ler configurações do arquivo .sync-config.ini
load_config_file() {
    local config_file="${1:-$CONFIG_INI}"
    
    if [ ! -f "$config_file" ]; then
        return 1
    fi
    
    log "INFO" "📄 Carregando configurações de: $config_file"
    
    while IFS='=' read -r key value; do
        # Ignorar comentários e linhas vazias
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        
        # Remover espaços em branco e aspas
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^["'\'']*//;s/["'\'']*$//')
        
        case "$key" in
            HOST) [ -z "$HOST" ] && HOST="$value" ;;
            REMOTE_PATH) [ -z "$REMOTE_PATH" ] && REMOTE_PATH="$value" ;;
            USER) [ -z "$USER" ] && USER="$value" ;;
            GROUP) [ -z "$GROUP" ] && GROUP="$value" ;;
            SSH_KEY) [ -z "$SSH_KEY" ] && SSH_KEY="$value" ;;
            LOCAL_PATH) [ -z "$LOCAL_PATH" ] && LOCAL_PATH="$value" ;;
            CHMOD_DIRS) [ -z "$CHMOD_DIRS" ] && CHMOD_DIRS="$value" ;;
            CHMOD_FILES) [ -z "$CHMOD_FILES" ] && CHMOD_FILES="$value" ;;
            CHMOD_DIRS_EXIT) [ -z "$CHMOD_DIRS_EXIT" ] && CHMOD_DIRS_EXIT="$value" ;;
            CHMOD_FILES_EXIT) [ -z "$CHMOD_FILES_EXIT" ] && CHMOD_FILES_EXIT="$value" ;;
            DEBOUNCE_TIME) [ -z "$DEBOUNCE_TIME" ] && DEBOUNCE_TIME="$value" ;;
            IGNORE_FILES)
                if [ ${#IGNORE_FILES[@]} -eq 0 ] && [ -n "$value" ]; then
                    IFS=',' read -ra IGNORE_FILES <<< "$value"
                fi
                ;;
        esac
    done < "$config_file"
    
    return 0
}

# Função para validar configurações obrigatórias
validate_config() {
    local errors=()
    
    [ -z "$HOST" ] && errors+=("HOST")
    [ -z "$REMOTE_PATH" ] && errors+=("REMOTE_PATH")
    [ -z "$USER" ] && errors+=("USER")
    [ -z "$GROUP" ] && errors+=("GROUP")
    [ -z "$SSH_KEY" ] && errors+=("SSH_KEY")
    
    if [ ${#errors[@]} -gt 0 ]; then
        print_colored "$RED" "\n❌ Configurações obrigatórias faltando:"
        for err in "${errors[@]}"; do
            print_colored "$RED" "   • $err"
        done
        print_colored "$YELLOW" "\n💡 Soluções:"
        print_colored "$YELLOW" "   1. Execute 'sync-dev --init' para criar arquivo de configuração"
        print_colored "$YELLOW" "   2. Edite .sync-config.ini e preencha as configurações"
        print_colored "$YELLOW" "   3. Ou use flags: sync-dev --host=... --remote-path=... --user=... --group=... --ssh-key=...\n"
        return 1
    fi
    
    # Definir valores padrão se não configurados
    [ -z "$LOCAL_PATH" ] && LOCAL_PATH="$(pwd)"
    [ -z "$CHMOD_DIRS" ] && CHMOD_DIRS="775"
    [ -z "$CHMOD_FILES" ] && CHMOD_FILES="664"
    [ -z "$CHMOD_DIRS_EXIT" ] && CHMOD_DIRS_EXIT="775"
    [ -z "$CHMOD_FILES_EXIT" ] && CHMOD_FILES_EXIT="664"
    [ -z "$DEBOUNCE_TIME" ] && DEBOUNCE_TIME="2"
    
    # Definir IGNORE_FILES padrão se vazio
    if [ ${#IGNORE_FILES[@]} -eq 0 ]; then
        IGNORE_FILES=(".git" "node_modules" "dist" "*.log" "vendor" "tmp" "composer.lock" "ssh_key" ".gitignore" ".DS_Store" "logs")
    fi
    
    return 0
}

# Carrega o estado anterior do arquivo INF e verifica se config atual existe
load_sync_state() {
    CONFIG_EXISTS=0  # Flag: 0=não existe, 1=existe
    
    if [ -f "$CONFIG_FILE" ]; then
        # Ler linha por linha (formato: path|user|group|chmod_dirs|chmod_files|timestamp)
        while IFS='|' read -r saved_path saved_user saved_group saved_chmod_dirs saved_chmod_files saved_timestamp; do
            # Ignorar linhas vazias e comentários
            [[ -z "$saved_path" || "$saved_path" =~ ^# ]] && continue
            
            # Remover espaços em branco
            saved_path=$(echo "$saved_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            saved_user=$(echo "$saved_user" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            saved_group=$(echo "$saved_group" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            saved_chmod_dirs=$(echo "$saved_chmod_dirs" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            saved_chmod_files=$(echo "$saved_chmod_files" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Verificar se a config atual já existe com mesmas permissões
            if [ "$saved_path" = "$REMOTE_PATH" ] && \
               [ "$saved_user" = "$USER" ] && \
               [ "$saved_group" = "$GROUP" ] && \
               [ "$saved_chmod_dirs" = "$CHMOD_DIRS" ] && \
               [ "$saved_chmod_files" = "$CHMOD_FILES" ]; then
                CONFIG_EXISTS=1
                log "INFO" "📄 Configuração encontrada no histórico: $saved_path|$saved_user|$saved_group|$saved_chmod_dirs|$saved_chmod_files ($saved_timestamp)"
                break
            fi
        done < "$CONFIG_FILE"
        
        if [ $CONFIG_EXISTS -eq 0 ]; then
            log "INFO" "📄 Configuração atual não encontrada no histórico ou permissões mudaram (${REMOTE_PATH}|${USER}|${GROUP}|${CHMOD_DIRS}|${CHMOD_FILES})"
        fi
    else
        log "INFO" "📄 Arquivo de estado não existe, será criado: $CONFIG_FILE"
    fi
}

# Salva o estado atual no arquivo INF (adiciona nova entrada ou atualiza existente)
save_sync_state() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local new_entry="${REMOTE_PATH}|${USER}|${GROUP}|${CHMOD_DIRS}|${CHMOD_FILES}|${timestamp}"
    local temp_file=$(mktemp)
    local found=0
    
    # Se o arquivo existe, ler e atualizar ou adicionar
    if [ -f "$CONFIG_FILE" ]; then
        while IFS='|' read -r saved_path saved_user saved_group saved_chmod_dirs saved_chmod_files saved_timestamp; do
            # Preservar comentários e linhas vazias
            if [[ -z "$saved_path" || "$saved_path" =~ ^# ]]; then
                echo "${saved_path}|${saved_user}|${saved_group}|${saved_chmod_dirs}|${saved_chmod_files}|${saved_timestamp}" >> "$temp_file"
                continue
            fi
            
            # Se encontrar a config atual (path+user+group), atualizar com novas permissões e timestamp
            if [ "$saved_path" = "$REMOTE_PATH" ] && \
               [ "$saved_user" = "$USER" ] && \
               [ "$saved_group" = "$GROUP" ]; then
                echo "$new_entry" >> "$temp_file"
                found=1
            else
                # Preservar outras entradas
                echo "${saved_path}|${saved_user}|${saved_group}|${saved_chmod_dirs}|${saved_chmod_files}|${saved_timestamp}" >> "$temp_file"
            fi
        done < "$CONFIG_FILE"
        
        # Se não encontrou, adicionar no final
        if [ $found -eq 0 ]; then
            echo "$new_entry" >> "$temp_file"
        fi
        
        mv "$temp_file" "$CONFIG_FILE"
    else
        # Criar arquivo novo com cabeçalho
        cat > "$CONFIG_FILE" << EOF
# Arquivo de estado de sincronização SSH
# Formato: REMOTE_PATH|USER|GROUP|CHMOD_DIRS|CHMOD_FILES|TIMESTAMP
# Gerado automaticamente
$new_entry
EOF
    fi
    
    chmod 600 "$CONFIG_FILE"
    log "INFO" "💾 Estado salvo/atualizado em $CONFIG_FILE (dirs=$CHMOD_DIRS, files=$CHMOD_FILES)"
}

# Verifica se precisa aplicar permissões (configuração não existe no histórico)
needs_permission_setup() {
    # Se CONFIG_EXISTS=0, precisa aplicar permissões
    # Se CONFIG_EXISTS=1, já foi aplicado antes
    if [ $CONFIG_EXISTS -eq 0 ]; then
        return 0  # true - precisa configurar
    fi
    
    return 1  # false - já configurado
}

set_default_remote_permissions() {
    SOCK="$HOME/.ssh/cm_%r@%h:%p"
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -M -S "$SOCK" -fN "$USER@$HOST"

    log "INFO" "🔐 Aplicando grupo padrão remoto ($GROUP)..."
    ssh -S "$SOCK" -i "$SSH_KEY" "$USER@$HOST" "sudo chown -R ${USER}:${GROUP} ${REMOTE_PATH} >> /tmp/last_logs.log 2>&1"
    log "INFO" "✅ aplicado grupo padrão remoto ($GROUP)"
    
    log "INFO" "🔐 Aplicando permissões padrão remotas (dirs=$CHMOD_DIRS, files=$CHMOD_FILES)..."
    ssh -S "$SOCK" -i "$SSH_KEY" "$USER@$HOST" "sudo find ${REMOTE_PATH} -type d -exec chmod ${CHMOD_DIRS} {} + >> /tmp/last_logs.log 2>&1"
    log "INFO" "✅ aplicado permissões padrão diretórios (dirs=$CHMOD_DIRS)"
    log "INFO" "✅ aplicando permissões padrão arquivos (files=$CHMOD_FILES)"
    ssh -S "$SOCK" -i "$SSH_KEY" "$USER@$HOST" "sudo find ${REMOTE_PATH} -type f -exec chmod ${CHMOD_FILES} {} + >> /tmp/last_logs.log 2>&1"
    log "INFO" "✅ aplicado permissões padrão arquivos (files=$CHMOD_FILES)"
    ssh -S "$SOCK" -O exit -i "$SSH_KEY" "$USER@$HOST"
    
    # Salvar estado atual
    save_sync_state
}


# Função para exibir log com timestamp
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Função para exibir mensagens coloridas
print_colored() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Função para criar diretório de logs se não existir
setup_log_dir() {
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        log "INFO" "📁 Diretório de logs criado: $LOG_DIR"
    fi
}

# Função para validar chave SSH
validate_ssh_key() {
    if [ ! -f "$SSH_KEY" ]; then
        log "ERROR" "Chave SSH não encontrada: $SSH_KEY"
        print_colored "$RED" "❌ Erro: Arquivo de chave SSH '$SSH_KEY' não encontrado!"
        exit 1
    fi
    
    chmod 600 "$SSH_KEY"
    log "INFO" "🔑 Chave SSH configurada: $SSH_KEY"
}

# Função para testar conexão SSH
test_ssh_connection() {
    print_colored "$YELLOW" "🛜 Testando conexão SSH..."
    log "INFO" "Testando conexão com $USER@$HOST"
    
    if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER@$HOST" "exit" 2>/dev/null; then
        print_colored "$GREEN" "✅ Conexão SSH estabelecida com sucesso!"
        log "INFO" "Conexão SSH OK"
        
        # Verificar se rsync está instalado no servidor remoto
        print_colored "$YELLOW" "🔍 Verificando rsync no servidor remoto..."
        if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$USER@$HOST" "command -v rsync" &>/dev/null; then
            print_colored "$GREEN" "✅ rsync disponível no servidor remoto"
            log "INFO" "rsync disponível no servidor remoto"
        else
            print_colored "$RED" "❌ rsync NÃO está instalado no servidor remoto!"
            print_colored "$YELLOW" "\n📋 Para corrigir, conecte no servidor e instale:"
            print_colored "$YELLOW" "   ssh -i $SSH_KEY $USER@$HOST"
            print_colored "$YELLOW" "   sudo apt-get install rsync  # ou yum/dnf install rsync"
            log "ERROR" "rsync não disponível no servidor remoto"
            exit 1
        fi
        
        return 0
    else
        print_colored "$RED" "❌ Falha ao conectar via SSH!"
        log "ERROR" "Falha na conexão SSH"
        exit 1
    fi
}

# Função para construir opções de exclusão do rsync (usa array para evitar globbing local)
build_rsync_excludes() {
    RSYNC_EXCLUDES=()
    for item in "${IGNORE_FILES[@]}"; do
        RSYNC_EXCLUDES+=("--exclude=$item")
    done
}

# Função para sincronizar arquivos
sync_files() {
    local sync_type=${1:-"manual"}
    local destination="$USER@$HOST:$REMOTE_PATH"
    
    log "INFO" "🔄 Iniciando sincronização ($sync_type)..."
    print_colored "$BLUE" "🔄 Sincronizando arquivos..."
    
    # Criar arquivo temporário para capturar stderr
    local error_file=$(mktemp)
    
    # Garantir que LOCAL_PATH termina com / para sincronizar conteúdo, não o diretório
    local source_path="${LOCAL_PATH%/}/"

    # Construir array seguro de exclusões
    build_rsync_excludes
    
    # Executar rsync com opções inteligentes
    rsync -rlptDvz \
        --update \
        --progress \
        --delete \
        --human-readable \
        --no-perms \
        --no-owner \
        --no-group \
        --no-times \
        -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
        "${RSYNC_EXCLUDES[@]}" \
        "$source_path" \
        "$destination" 2>"$error_file" | while IFS= read -r line; do
            echo "$line" >> "$LOG_FILE"
            # Mostrar apenas linhas relevantes no terminal
            if [[ "$line" =~ ^sent || "$line" =~ ^total || "$line" =~ speedup ]]; then
                echo "  $line"
            fi
        done
    
    local rsync_status=${PIPESTATUS[0]}
    
    if [ $rsync_status -eq 0 ]; then
        print_colored "$GREEN" "✅ Sincronização concluída com sucesso!"
        log "INFO" "✅ Sincronização concluída com sucesso"
        
        # Aplicar grupo e permissões no servidor remoto usando as variáveis (com verificação)
        print_colored "$YELLOW" "🔐 Ajustando grupo ($GROUP) e permissões remotas (dirs=$CHMOD_DIRS, files=$CHMOD_FILES)..."
        
        # Lock para evitar execuções duplicadas
        local lock_file="/tmp/sync_perms_$$.lock"
        if [ -f "$lock_file" ]; then
            log "WARN" "⚠️ Comando de permissões já está rodando, pulando duplicata"
            rm -f "$error_file"
            return 0
        fi
        touch "$lock_file"
        
        # Criar comando único que aplica tudo e verifica
        remote_cmd="sudo chown -R :$GROUP '$REMOTE_PATH' 2>&1 && \
sudo find '$REMOTE_PATH' -type d -exec chmod $CHMOD_DIRS {} + 2>&1 && \
sudo find '$REMOTE_PATH' -type f -exec chmod $CHMOD_FILES {} + 2>&1 && \
echo 'PERMISSIONS_APPLIED_OK'"
        
        result=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$USER@$HOST" "$remote_cmd" 2>&1)
        
        rm -f "$lock_file"
        
        if echo "$result" | grep -q "PERMISSIONS_APPLIED_OK"; then
            print_colored "$GREEN" "✅ Grupo e permissões aplicados com sucesso no remoto"
            log "INFO" "Grupo remoto ajustado para :$GROUP e permissões aplicadas: dirs=$CHMOD_DIRS, files=$CHMOD_FILES"
            
            # Verificar se realmente foram aplicadas
            verify_cmd="stat -c '%a' '$REMOTE_PATH' && stat -c '%a' \$(find '$REMOTE_PATH' -maxdepth 1 -type f | head -1)"
            verify_result=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$USER@$HOST" "$verify_cmd" 2>/dev/null)
            log "DEBUG" "Verificação de permissões aplicadas: $verify_result"
        else
            print_colored "$RED" "⚠️ Falha ao aplicar grupo/permissões no remoto"
            log "WARN" "Falha ao ajustar grupo/permissões no remoto (grupo:$GROUP). Saída: $result"
        fi
        
        rm -f "$error_file"
        return 0
    else
        print_colored "$RED" "❌ Erro na sincronização!"
        log "ERROR" "❌ Falha na sincronização (código: $rsync_status)"
        
        # Exibir erro detalhado se existir
        if [ -s "$error_file" ]; then
            print_colored "$RED" "\n🔴 Detalhes do erro:"
            while IFS= read -r error_line; do
                print_colored "$RED" "  ⚠️  $error_line"
                log "ERROR" "⚠️  $error_line"
            done < "$error_file"
        fi
        
        rm -f "$error_file"
        return 1
    fi
}

# Função para verificar dependências
check_dependencies() {
    local missing_critical=0
    local missing_optional=0
    
    print_colored "$BLUE" "🔍 Verificando dependências...\n"
    
    # Verificar rsync (CRÍTICO)
    if ! command -v rsync &> /dev/null; then
        print_colored "$RED" "❌ rsync não está instalado (OBRIGATÓRIO)"
        print_colored "$YELLOW" "   Instale com:"
        print_colored "$YELLOW" "   • Ubuntu/Debian: sudo apt-get install rsync"
        print_colored "$YELLOW" "   • Fedora/CentOS: sudo yum install rsync"
        print_colored "$YELLOW" "   • macOS: brew install rsync"
        log "ERROR" "Dependência crítica não encontrada: rsync"
        missing_critical=1
    else
        print_colored "$GREEN" "✅ rsync instalado"
    fi
    
    # Verificar SSH (CRÍTICO)
    if ! command -v ssh &> /dev/null; then
        print_colored "$RED" "❌ ssh não está instalado (OBRIGATÓRIO)"
        log "ERROR" "Dependência crítica não encontrada: ssh"
        missing_critical=1
    else
        print_colored "$GREEN" "✅ ssh instalado"
    fi
    
    # Verificar inotifywait (OPCIONAL - apenas para watch)
    if ! command -v inotifywait &> /dev/null; then
        print_colored "$YELLOW" "⚠  inotifywait não instalado (opcional para monitoramento)"
        print_colored "$YELLOW" "   Instale com:"
        print_colored "$YELLOW" "   • Ubuntu/Debian: sudo apt-get install inotify-tools"
        print_colored "$YELLOW" "   • Fedora/CentOS: sudo yum install inotify-tools"
        log "WARN" "inotifywait não disponível - modo watch desabilitado"
        missing_optional=1
    else
        print_colored "$GREEN" "✅ inotifywait instalado"
    fi
    
    echo ""
    
    if [ $missing_critical -eq 1 ]; then
        print_colored "$RED" "❌ Dependências críticas faltando. Instale-as antes de continuar."
        exit 1
    fi
    
    return $missing_optional
}

# Função para monitorar mudanças e sincronizar automaticamente
watch_and_sync() {
    print_colored "$GREEN" "👁 Iniciando monitoramento de mudanças..."
    log "INFO" "Modo watch ativado"
    
    # Construir lista de exclusões para inotifywait (usa array para evitar globbing)
    INOTIFY_EXCLUDES=()
    for item in "${IGNORE_FILES[@]}"; do
        INOTIFY_EXCLUDES+=("--exclude" "$item")
    done
    
    # Variável para debounce
    local last_sync=0
    
    # Monitorar mudanças recursivamente
    inotifywait -m -r \
        -e modify,create,delete,move \
        "${INOTIFY_EXCLUDES[@]}" \
        "$LOCAL_PATH" 2>/dev/null | while read -r directory event filename; do
        
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_sync))
        
        # Debounce: apenas sincronizar se passaram X segundos desde a última sync
        if [ $time_diff -ge $DEBOUNCE_TIME ]; then
            print_colored "$YELLOW" "\n⚡ Mudança detectada: $event $filename"
            log "INFO" "⚡ Mudança detectada: $directory$event$filename"
            
            sleep 0.5  # Pequeno delay para garantir que o arquivo foi completamente escrito
            
            sync_files "auto"
            last_sync=$(date +%s)
            
            print_colored "$GREEN" "👁 Monitorando mudanças... (Ctrl+C para sair)"
        fi
    done
}

# Função para instalar o script no sistema
install_script() {
    local script_path="$(readlink -f "$0")"
    local install_path="/usr/local/bin/sync-dev"
    
    print_colored "$BLUE" "📦 Instalando sync-dev no sistema..."
    
    # Verificar se o script existe
    if [ ! -f "$script_path" ]; then
        print_colored "$RED" "❌ Erro: Script não encontrado em $script_path"
        exit 1
    fi
    
    # Copiar o script
    print_colored "$YELLOW" "📋 Copiando script para $install_path..."
    if sudo cp "$script_path" "$install_path"; then
        print_colored "$GREEN" "✅ Script copiado com sucesso"
    else
        print_colored "$RED" "❌ Erro ao copiar script"
        exit 1
    fi
    
    # Adicionar permissão de execução
    print_colored "$YELLOW" "🔐 Adicionando permissão de execução..."
    if sudo chmod +x "$install_path"; then
        print_colored "$GREEN" "✅ Permissão de execução adicionada"
    else
        print_colored "$RED" "❌ Erro ao adicionar permissão de execução"
        exit 1
    fi
    
    print_colored "$GREEN" "\n✨ Instalação concluída com sucesso!"
    print_colored "$BLUE" "\n📌 Agora você pode executar o comando 'sync-dev' de qualquer lugar.\n"
    exit 0
}

# Função para exibir ajuda
show_help() {
    cat << EOF
$(print_colored "$BLUE" "📖 Script de Sincronização SSH com Monitoramento")

Uso: sync-dev [opções]

🔧 Comandos:
    --init [arquivo]        Cria arquivo de configuração template
                           (padrão: .sync-config.ini)
    
    --install              Instala o script em /usr/local/bin/sync-dev
                           (requer sudo)
    
    --config arquivo        Usa arquivo de configuração específico
                           (padrão: .sync-config.ini no diretório atual)

🚀 Modos de Operação:
    --sync, -s             Executa sincronização única
    --watch, -w            Monitora e sincroniza automaticamente
    --help, -h             Exibe esta ajuda
    --check                Verifica dependências do sistema

⚙️  Configurações (sobrescrevem .sync-config.ini):
    --host=HOST            Host do servidor remoto
    --remote-path=PATH     Caminho no servidor remoto
    --user=USER            Usuário SSH
    --group=GROUP          Grupo para arquivos remotos
    --ssh-key=PATH         Caminho para chave SSH
    --local-path=PATH      Diretório local (padrão: atual)
    --chmod-dirs=MODE      Permissões de diretórios (padrão: 775)
    --chmod-files=MODE     Permissões de arquivos (padrão: 664)
    --debounce=SECONDS     Tempo de espera antes de sincronizar (padrão: 2)
    --ignore=LISTA         Arquivos/pastas ignorados (separados por vírgula)

📖 Exemplos:
    # Instalar o script no sistema (primeira vez)
    sudo bash sync-dev.sh --install
    
    # Criar arquivo de configuração
    sync-dev --init
    
    # Sincronizar uma vez usando .sync-config.ini
    sync-dev --sync
    
    # Monitorar com arquivo de configuração específico
    sync-dev --watch --config=/path/to/config.ini
    
    # Sobrescrever configurações via flags
    sync-dev --sync --host=server.com --user=admin --remote-path=/var/www
    
    # Verificar dependências
    sync-dev --check

⚙️  Arquivo de Configuração (.sync-config.ini):
    HOST=server.example.com
    REMOTE_PATH=/var/www/html
    USER=username
    GROUP=www-data
    SSH_KEY=/home/user/.ssh/id_rsa
    IGNORE_FILES=.git,node_modules,dist,*.log

EOF
}

# Função de limpeza ao sair
cleanup() {
    print_colored "$YELLOW" "\n\n👋 Encerrando sincronização..."
    log "INFO" "👋 Script finalizado pelo usuário"
    
    # Aplicar permissões de saída (proteção) - ASSÍNCRONO
    print_colored "$YELLOW" "🔒 Aplicando permissões de proteção ao sair (dirs=$CHMOD_DIRS_EXIT, files=$CHMOD_FILES_EXIT)..."
    log "INFO" "🔒 Aplicando permissões de saída: dirs=$CHMOD_DIRS_EXIT, files=$CHMOD_FILES_EXIT"
    
    # Comando remoto para aplicar permissões restritivas
    exit_perms_cmd="sudo chown -R :$GROUP '$REMOTE_PATH' 2>&1 && \
sudo find '$REMOTE_PATH' -type d -exec chmod $CHMOD_DIRS_EXIT {} + 2>&1 && \
sudo find '$REMOTE_PATH' -type f -exec chmod $CHMOD_FILES_EXIT {} + 2>&1 && \
echo 'EXIT_PERMISSIONS_APPLIED'"
    
    # Executar em background com timeout de 3 segundos
    (
        timeout 3 ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$USER@$HOST" "$exit_perms_cmd" > /tmp/exit_perms.log 2>&1
        if [ $? -eq 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ✅ Permissões de saída aplicadas com sucesso (dirs=$CHMOD_DIRS_EXIT, files=$CHMOD_FILES_EXIT)" >> "$LOG_FILE"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] ⚠️ Timeout ou falha ao aplicar permissões de saída" >> "$LOG_FILE"
        fi
    ) &
    
    # Aguardar no máximo 2 segundos antes de sair
    local wait_pid=$!
    local waited=0
    while kill -0 $wait_pid 2>/dev/null && [ $waited -lt 2 ]; do
        sleep 0.5
        waited=$((waited + 1))
    done
    
    if kill -0 $wait_pid 2>/dev/null; then
        print_colored "$YELLOW" "⏱️  Encerrando (permissões sendo aplicadas em background)..."
    else
        print_colored "$GREEN" "✅ Permissões de saída aplicadas"
    fi
    
    exit 0
}

# ===============================================
# Parsing de Argumentos
# ===============================================

# Função de parsing de argumentos
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config=*)
                CONFIG_INI="${1#*=}"
                shift
                ;;
            --config)
                shift
                CONFIG_INI="$1"
                shift
                ;;
            --host=*)
                HOST="${1#*=}"
                shift
                ;;
            --remote-path=*)
                REMOTE_PATH="${1#*=}"
                shift
                ;;
            --user=*)
                USER="${1#*=}"
                shift
                ;;
            --group=*)
                GROUP="${1#*=}"
                shift
                ;;
            --ssh-key=*)
                SSH_KEY="${1#*=}"
                shift
                ;;
            --local-path=*)
                LOCAL_PATH="${1#*=}"
                shift
                ;;
            --chmod-dirs=*)
                CHMOD_DIRS="${1#*=}"
                shift
                ;;
            --chmod-files=*)
                CHMOD_FILES="${1#*=}"
                shift
                ;;
            --debounce=*)
                DEBOUNCE_TIME="${1#*=}"
                shift
                ;;
            --ignore=*)
                IFS=',' read -ra IGNORE_FILES <<< "${1#*=}"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--check)
                MODE="check"
                shift
                ;;
            -s|--sync)
                MODE="sync"
                shift
                ;;
            -w|--watch)
                MODE="watch"
                shift
                ;;
            --install)
                install_script
                ;;
            *)
                print_colored "$RED" "❌ Opção desconhecida: $1"
                print_colored "$YELLOW" "Use --help para ver as opções disponíveis."
                exit 1
                ;;
        esac
    done
}

# ===============================================
# Main
# ===============================================

main() {
    # Setup inicial
    setup_log_dir
    
    # Verificar se é comando --init primeiro (não precisa de configuração)
    if [[ "$1" == "--init" ]]; then
        shift
        create_config_template "${1:-.sync-config.ini}"
        exit 0
    fi
    
    # Verificar se é comando --install (não precisa de configuração)
    if [[ "$1" == "--install" ]]; then
        install_script
    fi
    
    # Modo padrão
    MODE="sync"
    
    # Parse argumentos
    parse_arguments "$@"
    
    # Tentar carregar configurações do arquivo .sync-config.ini
    if ! load_config_file "$CONFIG_INI"; then
        log "WARN" "⚠️  Arquivo de configuração não encontrado: $CONFIG_INI"
    fi
    
    # Validar configurações obrigatórias
    if ! validate_config; then
        exit 1
    fi
    
    # Capturar Ctrl+C para limpeza
    trap cleanup SIGINT SIGTERM
    
    # Banner
    print_colored "$BLUE" "╔══════════════════════════════════════╗"
    print_colored "$BLUE" "║  🚀 Sincronização SSH Inteligente    ║"
    print_colored "$BLUE" "╚══════════════════════════════════════╝"
    echo ""
    
    # Executar modo selecionado
    case "$MODE" in
        check)
            check_dependencies
            exit $?
            ;;
        sync)
            check_dependencies
            validate_ssh_key
            test_ssh_connection
            
            # Carregar estado de sincronização
            load_sync_state
            
            # Verificar se precisa configurar permissões iniciais
            if needs_permission_setup; then
                set_default_remote_permissions
            fi
            
            sync_files "manual"
            exit $?
            ;;
        watch)
            check_dependencies
            if [ $? -eq 1 ]; then
                print_colored "$RED" "❌ inotifywait não disponível. Modo watch não pode ser usado."
                exit 1
            fi
            
            validate_ssh_key
            test_ssh_connection
            
            # Carregar estado de sincronização
            load_sync_state
            
            # Verificar se precisa configurar permissões iniciais
            if needs_permission_setup; then
                set_default_remote_permissions
            fi
            
            # Sincronização inicial
            sync_files "initial"
            
            # Iniciar monitoramento
            print_colored "$GREEN" "\n✨ Tudo pronto! Monitorando em tempo real...\n"
            watch_and_sync
            ;;
    esac
}

# Executar main
main "$@"