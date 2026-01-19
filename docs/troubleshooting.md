---
title: Troubleshooting / FAQ
---

{% include theme-switcher.html %}

## 🛠 Troubleshooting — Soluções rápidas

Abaixo estão problemas comuns, causas prováveis e como coletar informações para depuração.

### Falha na conexão SSH
Sintoma: `Falha na conexão SSH` ou timeout.
- Verifique que a chave e o usuário estejam corretos:
  ```bash
  ssh -i /caminho/para/chave -v user@host
  ```
- Mensagens `Permission denied` indicam problema na chave ou no usuário.
- Certifique-se das permissões da chave: `chmod 600 /caminho/para/chave`.

### rsync não está instalado / erros do rsync
Sintoma: mensagem dizendo que `rsync` não está disponível no remoto ou local.
- Instale no servidor remoto: `ssh user@host sudo apt-get install rsync` (ou `yum/dnf` conforme distro).
- Para depurar uma transferência, rode o `rsync` com `--dry-run -vv --stats` para ver o que seria transferido:
  ```bash
  rsync -avz --dry-run --progress src/ user@host:/dest/
  ```

### Erro ao aplicar permissões remotas (sudo)
Sintoma: falha ao executar `chown`/`chmod` remotamente.
- Teste o comando manualmente via SSH para ver a saída real:
  ```bash
  ssh -i /caminho/para/chave user@host "sudo chown -R :group /var/www && sudo find /var/www -type f -exec chmod 664 {} +"
  ```
- Verifique `/tmp/last_logs.log` no remoto (o script escreve logs de comando remoto ali):
  ```bash
  ssh user@host "sudo cat /tmp/last_logs.log"
  ```
- Considere restringir sudoers para permitir apenas os comandos necessários (veja docs/permissions.md).

### inotifywait não instalado ou limite de watches
Sintoma: `watch` não detecta mudanças ou informa que `inotifywait` não está disponível.
- Instale localmente: `sudo apt-get install inotify-tools`.
- Se houver muitas pastas, aumente o limite de watches:
  ```bash
  sudo sysctl fs.inotify.max_user_watches=524288
  # para persistir, adicione em /etc/sysctl.conf
  ```

### Exclusões com padrões falhando
Sintoma: arquivos que deveriam ser excluídos não são ou padrões são expandidos localmente.
- Use `--ignore` com padrões corretos: `.git,node_modules,*.log`.
- O script já trata exclusões usando arrays (evita globbing local). Para testar, rode com `--sync --verbose` e verifique o que foi transferido.

### Logs / como coletar evidências
- Logs locais: `./logs/sync.log` (use `tail -f logs/sync.log`).
- Logs remotos temporários: `/tmp/last_logs.log` (conteúdo do último comando sudo remoto).
- Para relatórios de bugs, inclua:
  - Saída de `sync-dev --check`
  - As últimas 50 linhas de `logs/sync.log`
  - Saída `ssh -v` e `/tmp/last_logs.log` do remoto

### Permissões do arquivo de configuração/estado
- O arquivo de estado é salvo em `~/.server-sync.inf` com `chmod 600`.
- O template criado por `sync-dev --init` também é ajustado para `chmod 600` por padrão.

### Performance / tempo de debounce
- Ajuste `DEBOUNCE_TIME` no `.sync-config.ini` para evitar sincronizações muito frequentes em projetos com muitas alterações.

---

Se o problema persistir, abra uma issue no repositório com as informações acima e, se possível, um `--dry-run` e as saídas de log para diagnóstico rápido.
