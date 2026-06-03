# Fase 4: Automação com Ansible via Semaphore

Este documento descreve a automação de configuração (Fase 4) usando o conteúdo real em `ansible/` do repositório. O Ansible é responsável por configurar os LXC provisionados pelo Terraform — instalar pacotes, criar o usuário do Semaphore, injetar chaves SSH e executar validações.

Resumo rápido:
- Inventários: `ansible/invs/lxc/hosts`
- Roles principais: `ansible/roles/bootstrap` e `ansible/roles/ping-alunos`
- Playbooks de uso: `ansible/bootstrap-infra.yaml`, `ansible/ping-alunos.yml`

## 1. Organização do código

O diretório `ansible/` contém playbooks, inventários e roles usados pelo Semaphore. A organização relevante é:

- `ansible/invs/lxc/hosts` — inventário dos contêineres dos alunos
- `ansible/roles/bootstrap/tasks/main.yml` — tarefas de bootstrap (update, pacotes, usuário `semaphore`, injeção de chave)
- `ansible/roles/ping-alunos/tasks/main.yml` — role simples de verificação (ping + debug)
- `ansible/ping-alunos.yml` — playbook de teste que executa a role de *ping*
- `ansible/bootstrap-infra.yaml` — playbook orquestrador com fases (dinâmico, validações, instalação)

Use esses arquivos como fonte da verdade ao configurar tarefas no Semaphore.

## 2. Inventário

O inventário está em `ansible/invs/lxc/hosts` e contém entradas como:

```ini
[alunos]
aluno-01 ansible_host=10.0.40.201
aluno-02 ansible_host=10.0.40.202

[alunos:vars]
local="LAB REDES"
equipamento="LXC"
```

Este inventário é usado pelos playbooks de teste e pelo bootstrap. Para execuções no Semaphore, você pode manter esse inventário no repositório ou construir um inventário dinâmico a partir das variáveis que o Semaphore recebe (veja `bootstrap-infra.yaml`).

## 3. Role de bootstrap (configuração inicial)

A role `bootstrap` (arquivo `ansible/roles/bootstrap/tasks/main.yml`) executa, entre outros passos:

- Atualização do APT e upgrade do sistema
- Instalação de pacotes essenciais (e.g. `python3`, `sudo`, `curl`, `locales`)
- Configuração de timezone e locale
- Criação do grupo `semaphore` e do usuário `semaphore`
- Configuração de sudo sem senha para `semaphore`
- Busca da chave SSH pública no Vault e injeção no `authorized_keys` do usuário `semaphore`

A busca da chave utiliza lookup para o Vault (variáveis de ambiente `VAULT_TOKEN` e `VAULT_ADDR` são esperadas no ambiente do Semaphore):

- A key pública é obtida e armazenada em `vault_ssh_key` e em seguida aplicada via `authorized_key`.

Observação: o playbook presume que a execução inicial (pelo menos do inventário dinâmico) é realizada como `root` ou com credenciais que permitam criar o usuário `semaphore`. Posteriormente as fases usam o usuário `semaphore` para executar tarefas seguras.

## 4. Playbooks principais

- `ansible/ping-alunos.yml` — Playbook curto para testar conectividade contra o grupo `alunos`. Útil para validar acesso SSH e inventário.

```yaml
- name: Teste de Conectividade com Alunos
  hosts: alunos
  gather_facts: true
  roles:
  - ping-alunos
```

- `ansible/bootstrap-infra.yaml` — Orquestrador mais completo que contém fases: construção de inventário dinâmico (recebendo a lista `lxcs` do Semaphore), validações de conectividade, verificações de sistema/rede e instalação de ferramentas (fase de bootstrap completa). Use este playbook para rodar a configuração centralizada via Semaphore.

## 5. Fluxo sugerido no Semaphore

1. Crie um repositório Git (privado) contendo todo o diretório `ansible/` e adicione-o ao Semaphore (Repositories).

  Neste projeto foi criado um repositório Git privado separado para o código Ansible, seguindo a mesma abordagem adotada para o Terraform. O Semaphore foi configurado para apontar para esse repositório e puxar os playbooks/roles a cada execução.
2. Configure variáveis de ambiente no Semaphore:
   - `VAULT_ADDR` e `VAULT_TOKEN` (ou configure integração com Vault conforme seu fluxo)
   - quaisquer outras variáveis necessárias pelo playbook (ex.: lista `lxcs` quando usar inventário dinâmico)
3. Crie um template/task que execute `ansible-playbook ansible/bootstrap-infra.yaml` (ou `ansible/ping-alunos.yml` para testes rápidos).
4. Execute em modo *dry-run* inicialmente (adapte com `--check` se necessário) para validar inventário e conexões.

Exemplo de comando (podendo ser usado como step no Semaphore):

```bash
ansible-playbook ansible/ping-alunos.yml -i ansible/invs/lxc/hosts
# ou para o bootstrap completo (o Semaphore passa variáveis para o playbook)
ansible-playbook ansible/bootstrap-infra.yaml
```

## 6. Observações operacionais e segurança

- A primeira execução de bootstrap realiza operações como atualização de pacotes e criação do usuário `semaphore`. Garanta que a conta que executa esse playbook tenha privilégios de root (normalmente via chaves SSH injetadas pelo Terraform).
- A chave SSH do usuário `semaphore` é lida do Vault — proteja o token do Vault no Semaphore (use secret env vars).
- O playbook `bootstrap-infra.yaml` contém validações de rede e sistema; falhas nessas validações devem ser tratadas antes de avançar para instalações em massa.

## 7. Debug e resultados típicos

- Use `ansible -m ping all -i ansible/invs/lxc/hosts` para um teste rápido.
- O playbook `ping-alunos` retorna mensagens de debug com as variáveis `equipamento` e `local`, confirmando que o inventário foi lido corretamente.

## 8. Referências e próximos passos

- Ver os arquivos fonte em: `ansible/invs/lxc/hosts`, `ansible/roles/bootstrap/tasks/main.yml`, `ansible/ping-alunos.yml`, `ansible/bootstrap-infra.yaml`.
- Se desejar, eu posso:
  - adicionar um `ansible.cfg` mínimo ao repositório,
  - criar um playbook de *rollback* simples,
  - ou gerar um template de pipeline do Semaphore com passos e variáveis exemplo.

---

Arquivo atualizado automaticamente a partir do conteúdo de `ansible/`.
