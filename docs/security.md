---
title: Segurança
---

## 🔒 Recomendações de Segurança

- **Verifique o script** antes de executar quando baixar diretamente da web:

```bash
curl -L https://raw.githubusercontent.com/dinabox-web-team/sync-dev-tool/main/sync-dev.sh -o sync-dev.sh
less sync-dev.sh
shasum -a 256 sync-dev.sh
```

- **Use Releases/Tags** do GitHub sempre que possível (releases podem ter checksums ou assinaturas).

- **Permissões do arquivo de configuração**: o script cria o arquivo de estado em `~/.server-sync.inf` com `chmod 600`. Certifique‑se que o `.sync-config.ini` também esteja com permissões restritas (`chmod 600`).

- **Sudo remoto limitado**: O script executa `sudo chown` e `sudo find -exec chmod` no servidor remoto. Para reduzir risco, configure `/etc/sudoers` para permitir apenas os comandos necessários sem senha para o usuário usado pelo script.

- **Escape de variáveis**: o script trata caminhos e nomes de grupo com cuidado, mas não subestime entradas malformadas. Não coloque conteúdo arbitário em `REMOTE_PATH` ou em arquivos de config sem validação.

- **Logs**: evite versionar ou publicar logs que contenham informações sensíveis (paths internos, output de erros que contenham conteúdo de arquivos, etc).
