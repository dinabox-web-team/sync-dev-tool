---
title: GitHub Pages (Jekyll)
---

## 📣 Publicar a documentação no GitHub Pages

Para servir a documentação via GitHub Pages usando o conteúdo da pasta `/docs`:

1. Garanta que a branch **main** contenha a pasta `/docs` com os arquivos Jekyll (nós já criamos `/docs`).
2. No repositório GitHub, vá em **Settings → Pages**.
3. Em **Source**, selecione **Branch: main** e **/docs** como pasta. Salve.
4. Aguarde alguns minutos; o site ficará disponível em `https://<owner>.github.io/<repo>` (ex: `https://dinabox-web-team.github.io/sync-dev-tool`).

> Dica: use o tema `minima` no `_config.yml` (já configurado). Se preferir, adicione um workflow que construa a documentação automaticamente.
