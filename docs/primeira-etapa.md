# Primeira etapa (base) — passo a passo (Windows + GitHub)

## Resposta direta à sua dúvida
- **Eu não criei pasta no seu Windows.**
- No Raspberry, a pasta de trabalho será `/opt/homelab-setup` (padrão do Linux para esse tipo de script).
- Você pode deixar que o próprio `git clone` crie essa pasta automaticamente.

## 1) Primeiro boot do Raspberry (feito no Raspberry Pi Imager)
Na gravação do SD:
- Enable SSH
- Definir usuário/senha
- Configurar Wi-Fi (se não usar cabo)

## 2) Conectar por SSH do Windows
No `cmd`/PowerShell:

```powershell
ssh SEU_USUARIO@IP_DO_RASPBERRY
```

## 3) Baixar os scripts do seu GitHub (sem criar pasta manual)
Já conectado no Raspberry, rode exatamente:

```bash
sudo apt update
sudo apt install -y git
sudo git clone https://github.com/igorfronza/Raspberry /opt/homelab-setup
sudo chown -R "$USER":"$USER" /opt/homelab-setup
cd /opt/homelab-setup
```

> Observação: o `git clone ... /opt/homelab-setup` já cria a pasta automaticamente.

## 4) Preparar o arquivo de configuração

```bash
cp scripts/.env.example scripts/.env
nano scripts/.env
```

Ajuste no mínimo:
- `TZ_VALUE`
- `PI_HOSTNAME`
- Deixe `SSH_DISABLE_PASSWORD=0` por enquanto.

## 5) Executar a etapa 1

```bash
sudo bash scripts/deploy.sh
```

O `deploy.sh` roda a etapa base (`01-base.sh`) e salva log em `/var/log/homelab-setup/`.

## 6) Validar rapidamente

```bash
hostname
timedatectl
sudo ufw status
sudo systemctl status fail2ban --no-pager
```

## 7) Atualizações futuras (quando eu te entregar etapa 2, 3...)

```bash
cd /opt/homelab-setup
git pull
sudo bash scripts/deploy.sh
```

## Atenção
Só mude `SSH_DISABLE_PASSWORD=1` depois de confirmar login por chave SSH.
