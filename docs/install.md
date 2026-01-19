---
title: Install
---

## 🔧 Instalação

O comando `--install` copia o script para `/usr/local/bin/sync-dev` e adiciona permissão de execução.

### Comando de instalação (local)

```bash
sudo bash sync-dev.sh --install
```

> Observação: se o arquivo `sync-dev.sh` ainda não for executável você pode executar com `sudo bash sync-dev.sh --install` ou tornar executável primeiro: `chmod +x sync-dev.sh && sudo ./sync-dev.sh --install`.

### Nota de segurança
- Para operação segura, verifique o conteúdo do script antes de executá‑lo com `less` ou `shasum -a 256` (quando disponível).
- Em ambiente de produção, prefira criar um release no GitHub e verificar assinaturas/SHAs.

### Alternativa mais segura para copiar com permissões definidas
- Se você quiser um passo único, prefira usar `install` localmente (ex.: `sudo install -Dm755 sync-dev.sh /usr/local/bin/sync-dev`). O comando `install` copia e define permissões de forma atômica.
