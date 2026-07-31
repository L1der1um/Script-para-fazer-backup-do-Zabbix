# 💾 Zabbix Auto Backup

<p align="center">

![Bash](https://img.shields.io/badge/Bash-Script-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-Compatible-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Zabbix](https://img.shields.io/badge/Zabbix-5_|_6_|_7_LTS-D40000?style=for-the-badge)
![MySQL](https://img.shields.io/badge/MySQL-Compatible-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-Compatible-003545?style=for-the-badge&logo=mariadb&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

</p>

Script desenvolvido para realizar o **backup completo de ambientes Zabbix**, preservando o banco de dados e os principais arquivos do sistema.

Compatível com **Zabbix 5 LTS**, **Zabbix 6 LTS** e **Zabbix 7 LTS**, o script foi projetado para simplificar rotinas de backup, migração e recuperação de desastres (Disaster Recovery).

---

# 📦 Compatibilidade

O script foi desenvolvido para funcionar com:

| Versão | Compatibilidade |
|---------|:--------------:|
| ✅ Zabbix 5 LTS | ✔ |
| ✅ Zabbix 6 LTS | ✔ |
| ✅ Zabbix 7 LTS | ✔ |

Também é compatível com:

- MySQL
- MariaDB

---

# ✨ Funcionalidades

- 💾 Backup completo do banco de dados.
- 📦 Backup dos arquivos do Zabbix.
- 🗜️ Compressão automática em GZip.
- 🔍 Verificação das credenciais do banco antes do backup.
- ⚡ Backup online utilizando `--single-transaction`.
- 🛡️ Inclusão de:
  - Procedures
  - Triggers
  - Events
- 📋 Validação do arquivo gerado.
- 📊 Resumo do backup ao final.
- 🎨 Interface amigável no terminal.

---

# 📂 Estrutura dos backups

Os backups são armazenados automaticamente em:

```text
/backup_zabbix
```

Exemplo:

```text
/backup_zabbix

├── bkp_2026-07-30
│   ├── zabbix_db_20260730_182530.sql.gz
│   └── zabbix_dirs_2026-07-30.tar.gz
│
├── bkp_2026-07-29
│   ├── zabbix_db_20260729_182540.sql.gz
│   └── zabbix_dirs_2026-07-29.tar.gz
│
└── bkp_2026-07-28
    ├── zabbix_db_20260728_182525.sql.gz
    └── zabbix_dirs_2026-07-28.tar.gz
```

Cada execução cria automaticamente um novo diretório de backup organizado por data.

---

# 📦 Arquivos gerados

| Arquivo | Descrição |
|----------|-----------|
| `zabbix_db_*.sql.gz` | Backup do banco de dados |
| `zabbix_dirs_*.tar.gz` | Backup dos arquivos do Zabbix |

---

# 📂 O que é salvo?

## Banco de dados

O script exporta completamente o banco **zabbix**, incluindo:

- Hosts
- Templates
- Usuários
- Grupos
- Mapas
- Triggers
- Itens
- Descobertas
- Histórico de configurações
- Macros
- Dashboards
- Actions
- Media Types
- Scripts
- Todas as demais estruturas do banco

---

## Arquivos físicos

Também são compactados automaticamente:

```text
/etc/zabbix
/usr/share/zabbix
/usr/lib/zabbix
/var/log/zabbix
```

Esses diretórios incluem:

- Configurações
- Frontend
- Scripts
- Bibliotecas
- Logs
- Arquivos auxiliares

---

# ⚙️ Como funciona

O processo foi dividido em várias etapas para garantir um backup consistente.

---

## 1️⃣ Verificação

O script verifica:

- permissões de root;
- existência das dependências;
- criação do diretório de backup.

---

## 2️⃣ Credenciais

São solicitados:

- usuário do banco;
- senha do banco.

Essas credenciais são utilizadas apenas durante a execução.

---

## 3️⃣ Teste de conexão

Antes de iniciar o backup é realizado um teste de conexão com o banco.

Caso as credenciais estejam incorretas, o backup é interrompido.

---

## 4️⃣ Backup do banco

O backup é realizado utilizando:

```bash
mysqldump
```

com opções recomendadas para ambientes em produção:

- `--single-transaction`
- `--routines`
- `--triggers`
- `--events`
- `--default-character-set=utf8mb4`
- `--no-tablespaces`

O arquivo é compactado automaticamente em formato GZip.

---

## 5️⃣ Validação

Após a geração do dump o script verifica seu tamanho mínimo.

Essa etapa evita armazenar arquivos vazios ou corrompidos.

---

## 6️⃣ Backup dos arquivos

Em seguida é criado um arquivo compactado contendo todos os diretórios essenciais do Zabbix.

---

# 🔄 Fluxo do backup

```text
Verificar Root
        │
        ▼
Validar Dependências
        │
        ▼
Solicitar Credenciais
        │
        ▼
Testar Banco
        │
        ▼
Gerar Dump SQL
        │
        ▼
Compactar Banco
        │
        ▼
Compactar Arquivos
        │
        ▼
Resumo Final
```

---

# ▶️ Execução

Conceda permissão ao script:

```bash
chmod +x backup_zabbix.sh
```

Execute:

```bash
sudo ./backup_zabbix.sh
```

---

# 📋 Etapas exibidas

Durante a execução são exibidas mensagens semelhantes a:

```text
Iniciando backup...

Validando banco...

Gerando dump...

Compactando arquivos...

Resumo do backup...
```

---

# 🔒 Segurança

O script utiliza **Hot Backup** através do parâmetro:

```bash
--single-transaction
```

Esse método reduz a necessidade de interromper o banco durante a geração do backup, sendo recomendado para ambientes em produção com tabelas InnoDB.

Além disso:

- valida as credenciais;
- verifica o tamanho mínimo do arquivo gerado;
- remove automaticamente backups inválidos.

---

# 📌 Pré-requisitos

- Linux
- Bash
- MySQL ou MariaDB
- mysqldump
- gzip
- tar
- Permissão de root

---

# 📊 Exemplo de saída

```text
Resumo do backup

zabbix_db_20260730.sql.gz

zabbix_dirs_2026-07-30.tar.gz

Backup concluído em:

/backup_zabbix/bkp_2026-07-30
```

---

# ✅ Benefícios

- Compatível com Zabbix 5, 6 e 7 LTS
- Compatível com MySQL e MariaDB
- Backup online
- Compressão automática
- Estrutura organizada
- Processo automatizado
- Fácil recuperação
- Ideal para Disaster Recovery
- Compatível com o script **Zabbix Restore**

---

# 🛠️ Tecnologias utilizadas

- Bash
- MySQL
- MariaDB
- mysqldump
- gzip
- tar

---

# 🔗 Projetos relacionados

Este projeto faz parte de uma suíte de automação para o Zabbix:

- 🚀 **Zabbix 6 LTS Installer**
- 🚀 **Zabbix 7.0 LTS Installer**
- 💾 **Zabbix Backup**
- ♻️ **Zabbix Restore**

Juntos, esses scripts oferecem uma solução completa para implantação, backup e recuperação de ambientes Zabbix.

---

# 📄 Licença

Este projeto está licenciado sob a licença **MIT**.

Você pode utilizar, modificar e distribuir este projeto livremente, desde que mantenha os créditos e o texto da licença.

---

# 👨‍💻 Autor

Desenvolvido para automatizar o backup de ambientes **Zabbix 5 LTS, 6 LTS e 7 LTS**, garantindo consistência dos dados, organização dos backups e suporte a estratégias de Disaster Recovery em servidores Linux.
