# Primeira etapa (base) — passo a passo (Windows + GitHub)

## Resposta direta à sua dúvida
- **Eu não criei pasta no seu Windows.**
- No Raspberry, a pasta de trabalho será `/opt/homelab-setup` (padrão do Linux para esse tipo de script).
- Você pode deixar que o próprio `git clone` crie essa pasta automaticamente.

<<<<<<< ours
=======
## Estrutura recomendada no Windows (repo local)
Se você também mantém uma cópia local do projeto no Windows, use a pasta raiz do repositório (a pasta que contém `.git`) para executar comandos Git.

Estrutura recomendada:
- `docs/`
- `scripts/`
- `.gitkeep` (opcional)

Comandos básicos no PowerShell:

```powershell
cd "C:\caminho\para\Raspberry"
git status
git add .
git commit -m "Sua mensagem"
git push
```

## Deixar este ambiente apto para enviar direto ao GitHub (origin + autenticação)
Se você quiser que o próprio ambiente envie as mudanças para `github.com/igorfronza/Raspberry`, configure uma vez:

```bash
cd /workspace/Raspberry

# 1) conectar o repo local ao GitHub
git remote add origin https://github.com/igorfronza/Raspberry.git
# se já existir origin, atualize:
# git remote set-url origin https://github.com/igorfronza/Raspberry.git

# 2) conferir remoto
git remote -v

# 3) definir branch principal de trabalho para push
git branch -M work

# 4) primeiro push com upstream
git push -u origin work
```

Autenticação no GitHub:
- No primeiro `git push`, use seu usuário GitHub e um **Personal Access Token (PAT)** como senha.
- Escopo mínimo do token para repositório privado: `repo`.

Depois disso, o fluxo normal fica:

```bash
git add .
git commit -m "mensagem"
git push
```

>>>>>>> theirs
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
<<<<<<< ours
=======


## Etapa 2 (Storage) — depois da etapa 1
Atualize os arquivos e execute:

```bash
cd /opt/homelab-setup
git pull
nano scripts/.env
# preencha SMB_PASSWORD e confirme STORAGE_OWNER_USER
sudo bash scripts/02-storage.sh scripts/.env
```

Teste no Windows (Explorador de Arquivos):
- `\\IP_DO_RASPBERRY\\Storage-Publico`
- `\\IP_DO_RASPBERRY\\Storage-Privado`

Teste SFTP (WinSCP/FileZilla):
- Host: `IP_DO_RASPBERRY`
- Protocolo: SFTP
- Usuário/senha: usuário Linux do Raspberry
- Pasta: `/srv/homelab-storage`


## Etapa 3 (Pi-hole) — DNS da rede
No Raspberry:

```bash
cd /opt/homelab-setup
git pull
nano scripts/.env
# preencha PIHOLE_WEBPASSWORD
sudo bash scripts/03-pihole.sh scripts/.env
```

Acesse no navegador:
- `http://IP_DO_RASPBERRY:8080/admin`

Depois, no roteador, configure o DNS da rede para o IP do Raspberry.


## Etapa 4 (WireGuard VPN)
No Raspberry:

```bash
cd /opt/homelab-setup
git pull
nano scripts/.env
# preencha WG_HOST (IP público/DDNS) e WG_ADMIN_PASSWORD_HASH
sudo bash scripts/04-wireguard.sh scripts/.env
```

Acesse no navegador:
- `http://IP_DO_RASPBERRY:51821`

No painel do wg-easy, crie o cliente e importe o QR code no celular.


### Migração para wg-easy v14 (PASSWORD_HASH)
No Raspberry:

```bash
cd /opt/homelab-setup
sudo docker run --rm ghcr.io/wg-easy/wg-easy:14 wgpw "SUA_SENHA_FORTE"
# copie o hash para WG_ADMIN_PASSWORD_HASH no scripts/.env
nano scripts/.env
sudo bash scripts/04-wireguard.sh scripts/.env
```


## Etapa 5 (Home Assistant) — explicação simples
No Raspberry, rode exatamente nesta ordem:

```bash
cd /opt/homelab-setup
git pull
nano scripts/.env
# ajuste apenas HA_TZ se necessário
sudo bash scripts/05-homeassistant.sh scripts/.env
```

O que o script faz:
1. Instala Docker (se ainda não existir).
2. Cria a pasta de dados em `/opt/homeassistant/config` (ou `HA_BASE_DIR/config`).
3. Sobe o container `homeassistant` com `restart: unless-stopped`.
4. Libera a porta 8123 no UFW (quando UFW estiver instalado).

Acesse no navegador:
- `http://IP_DO_RASPBERRY:8123`

Validação rápida (se não abrir no navegador):

```bash
sudo docker ps | grep homeassistant
sudo docker logs --tail=100 homeassistant
sudo ss -lntp | grep 8123
```

Observações importantes:
- O primeiro start pode demorar alguns minutos.
- Neste setup a porta é **8123** (modo `network_mode: host`).
- Se você mudar `HA_HTTP_PORT` no `.env`, o script avisa e mantém 8123 para evitar configuração quebrada.

## Checklist curto (backup + segurança final)
Rode estes comandos no Raspberry (já com tudo instalado):

```bash
cd /opt/homelab-setup

# 1) Backup rápido dos arquivos de configuração dos containers
sudo tar -czf /opt/backup-homelab-$(date +%F).tar.gz \
  /opt/homeassistant/config \
  /opt/pihole \
  /opt/wireguard

# 2) Confirmar que os serviços estão ativos
sudo docker ps

# 3) Atualizar pacotes do sistema
sudo apt update && sudo apt -y upgrade

# 4) Garantir firewall ativo e somente SSH permitido (além das portas que você usa)
sudo ufw status verbose

# 5) Validar fail2ban no SSH
sudo systemctl status fail2ban --no-pager
sudo fail2ban-client status sshd

# 6) (Somente depois de validar login por chave SSH) desativar senha no SSH
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

Validação final no navegador:
- Home Assistant: `http://IP_DO_RASPBERRY:8123`
- Pi-hole: `http://IP_DO_RASPBERRY:8080/admin`
- wg-easy: `http://IP_DO_RASPBERRY:51821`

>>>>>>> theirs
