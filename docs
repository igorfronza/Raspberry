# Plano de instalação no Raspberry Pi OS Lite 64-bit

## Resposta curta
Faça **um script por serviço**, teste cada etapa, e depois use um **script orquestrador** para rodar tudo em sequência.

Tentar instalar Home Assistant + WireGuard + Pi-hole + servidor de arquivos “100% de uma vez” tende a dar mais retrabalho quando algo quebra (dependência, porta, DNS, firewall, disco externo, etc.).

## Estratégia recomendada (menos trabalhosa no fim)
1. Preparar base do sistema (update, pacotes essenciais, timezone, hostname).
2. Subir armazenamento/compartilhamento de arquivos.
3. Subir Pi-hole (DNS da rede).
4. Subir WireGuard (VPN).
5. Subir Home Assistant.
6. Fazer validações de saúde após cada serviço.
7. Só então automatizar “tudo” no orquestrador.

## Ordem sugerida e motivo
- **Servidor de arquivos primeiro**: já define disco, permissões, backup e caminhos.
- **Pi-hole antes do WireGuard**: facilita VPN já usando DNS interno.
- **WireGuard antes do Home Assistant**: você garante acesso remoto seguro para manutenção.
- **Home Assistant por último**: depende menos de infra mutável quando os outros já estão estáveis.

## Boa prática para SD “pronto”
- Deixe scripts em `/opt/homelab-setup`.
- Cada script deve ser idempotente (rodar 2x não estraga).
- Use arquivo `.env` com variáveis (domínio, IP fixo, interface, caminho de dados).
- Registre logs em `/var/log/homelab-setup/*.log`.
- Valide portas e serviços ao final de cada etapa.

## Exemplo de serviços
- Home Assistant: container (compose).
- WireGuard: `wg-easy` (container) ou nativo `wireguard-tools`.
- Pi-hole: container oficial.
- Arquivos: Samba + SFTP (OpenSSH) + opcional Nextcloud para acesso externo com interface web.

## Segurança mínima
- Usuário sem senha fraca.
- Chave SSH + desativar login por senha quando possível.
- Fail2ban para SSH.
- Atualizações automáticas de segurança.
- Backup do `docker-compose` e volumes críticos.

## Resultado prático
Você ganha um caminho com baixo risco:
- **Menos trabalhoso:** scripts por serviço + testes curtos.
- **Execução única depois:** `deploy.sh` chama tudo na ordem certa.
