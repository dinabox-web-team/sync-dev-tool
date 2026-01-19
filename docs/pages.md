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

### Build local (reproduzir ambiente GitHub Pages)

Para evitar problemas como `main.css` ausente localmente, instale as dependências do GitHub Pages e rode o servidor localmente:

```bash
# 1) Instalar bundler se necessário
gem install bundler --user-install

# 2) Instalar dependências (inclui o tema minima via github-pages)
bundle install

# 3) Servir a pasta docs localmente (porta 4000 por padrão)
bundle exec jekyll serve --source docs --watch

# Abra: http://localhost:4000
```

Se você vir erro de `main.css` ausente ao testar localmente, execute os passos acima; no GitHub Pages (remoto) o tema `minima` é provido automaticamente pela plataforma.
