---
title: Init
---

## 🧭 Inicialização (`--init`)

Crie um template de configuração no diretório atual:

```bash
sync-dev --init
# ou
sync-dev --init custom-config.ini
```

O arquivo criado (`.sync-config.ini` por padrão) contém chaves obrigatórias:

- `HOST` — host remoto
- `REMOTE_PATH` — caminho absoluto no servidor remoto
- `USER` — usuário SSH
- `GROUP` — grupo para arquivos remotos
- `SSH_KEY` — caminho para a chave privada local

O template define `chmod 600` no arquivo gerado. Não compartilhe sua chave privada e mantenha `SSH_KEY` apontando para um arquivo com permissões seguras.
