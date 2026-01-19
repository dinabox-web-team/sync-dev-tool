---
title: Running sync-dev as a systemd Service
---

{% include theme-switcher.html %}

## ⚙️ Executar `sync-dev --watch` como serviço (systemd)

Rodar `sync-dev` como um serviço permite que ele reinicie automaticamente e seja gerenciado pelo systemd.

### Exemplo de unit (system-wide)
Crie `/etc/systemd/system/sync-dev.service`:

```ini
[Unit]
Description=sync-dev watcher service
After=network.target

[Service]
Type=simple
User=deploy
Group=deploy
WorkingDirectory=/home/deploy/myapp
ExecStart=/usr/local/bin/sync-dev --watch --config=/home/deploy/myapp/.sync-config.ini
Restart=on-failure
RestartSec=10
Environment=HOME=/home/deploy

[Install]
WantedBy=multi-user.target
```

> Nota: substitua `deploy` e `WorkingDirectory` pelo usuário/diretório corretos. O serviço precisa de acesso à chave SSH (`SSH_KEY`) e à configuração `.sync-config.ini` com permissões seguras (chmod 600).

### Alternativa: systemd user service
Para executar como serviço do usuário (sem sudo), crie `~/.config/systemd/user/sync-dev.service` com `User` omitido e ative com `systemctl --user enable --now sync-dev`.

### Instalar e iniciar o serviço
```bash
# recarregar units
sudo systemctl daemon-reload
# habilitar e iniciar
sudo systemctl enable --now sync-dev.service
# ver status
sudo systemctl status sync-dev.service
# ver logs
sudo journalctl -u sync-dev.service -f
```

### Boas práticas
- Garanta que a chave SSH referenciada em `.sync-config.ini` exista e esteja com `chmod 600` para o usuário que roda o serviço.
- Prefira usar `--config` com caminho absoluto no `ExecStart`.
- Monitore logs (`journalctl` + `./logs/sync.log`) e configure rotações de log se necessário.

---

Se quiser, crio também um `systemd` example directory com um `deploy` playbook e um `README` de como testar a unidade com `systemd-run --user`.
