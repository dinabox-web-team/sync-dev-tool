---
title: Sync & Watch
---

{% include theme-switcher.html %}

## 🔁 Uso (sync / watch)

Sincronize uma vez:

```bash
sync-dev --sync
# ou sobrescrevendo configurações
sync-dev --sync --host=server.com --user=username --remote-path=/var/www/html --ssh-key=/home/user/.ssh/id_rsa
```

Monitorar e sincronizar automaticamente:

```bash
sync-dev --watch
```

Opções úteis:
- `--check` — verifica dependências (rsync, ssh, inotifywait)
- `--local-path` — especificar diretório local
- `--ignore` — lista separada por vírgula de padrões a ignorar (ex.: `.git,node_modules,dist`)

### Observação importante sobre caminhos
- Para sincronizar o *conteúdo* de um diretório (e não a pasta inteira dentro do destino), o script usa caminhos terminados em `/` internamente — comporta‑se como `rsync /src/ dest:`.
