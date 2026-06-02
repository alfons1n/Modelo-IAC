# Fase 4: Automação de Configurações com Ansible no Semaphore UI

Com a infraestrutura dos contêineres LXC já provisionada pelo Terraform (Fase 3), avançamos agora para a **Fase 4** do projeto: a automação das configurações internas utilizando o **Ansible**, orquestrado pela interface gráfica do **Semaphore UI**.

Enquanto o Terraform responde à pergunta *"O que deve existir?"* (criar máquinas, redes, discos), o Ansible responde à pergunta *"Como deve estar configurado?"* (instalar pacotes, configurar serviços, aplicar políticas). Juntos, eles completam o ciclo da Infraestrutura como Código.

> **Referências oficiais:**
> - Instalação do Semaphore: [semaphoreui.com/install](https://semaphoreui.com/install)
> - Documentação completa: [semaphoreui.com/docs](https://semaphoreui.com/docs)
> - Repositório de exemplo: [github.com/semaphoreui/semaphore-demo](https://github.com/semaphoreui/semaphore-demo)

---

## 1. Estrutura do Código Ansible (Organização por Roles)

Assim como qualquer linguagem de programação, o código Ansible pode ser escrito de várias maneiras. Porém, para manter a organização e facilitar o entendimento por terceiros, adotamos a mesma lógica do repositório oficial [semaphore-demo](https://github.com/semaphoreui/semaphore-demo), que separa os blocos essenciais de forma clara.

A nossa implementação encontra-se no diretório `semaphore/` deste repositório, com a seguinte estrutura:

![Estrutura de diretórios do Ansible no projeto](../../imagens/semaphore/semaphore-estrutura.png)

```
semaphore/
│
├── invs/                          ← Inventários (QUEM será acessado)
│   ├── proxmox/hosts              ← Cluster Proxmox
│   └── lxc/hosts                  ← Contêineres dos alunos
│
├── roles/                         ← Roles (O QUE será feito)
│   ├── ping-proxmox/tasks/main.yml
│   ├── ping-alunos/tasks/main.yml
│   └── start-alunos/tasks/main.yml
│
├── ping-proxmox.yml               ← Playbooks (COMO orquestrar)
├── ping-alunos.yml
├── start-proxmox.yml
├── start.yml
└── stop-proxmox.yml
```

### Entendendo os 3 Blocos Essenciais

Para que qualquer pessoa consiga compreender e replicar o projeto, é fundamental entender o papel de cada bloco:

**📋 Inventário (Inventory)** — *QUEM será acessado*
> O inventário é a "lista de alvos" do Ansible. É um arquivo de texto simples (formato INI) que declara os endereços IP ou nomes das máquinas que serão gerenciadas. Sem um inventário definido, o Ansible não sabe para onde enviar os comandos. **Nada funciona sem ele.**

**🔧 Roles** — *O QUE será feito em cada alvo*
> Uma Role é um "pacote de instruções" reutilizável. Ela agrupa as tarefas (tasks), variáveis, templates e configurações relacionadas a uma única responsabilidade. Por exemplo: a role `ping-proxmox` contém especificamente as tarefas de verificar a conectividade com o cluster Proxmox. Essa separação permite reaproveitar a mesma role em diferentes playbooks e projetos.

**📖 Playbooks (Tasks)** — *COMO orquestrar a execução*
> A Playbook é o "documento maestro" que conecta QUEM (inventário) com O QUE (roles). Ela define: *"Execute a role X nos hosts do grupo Y."* É o arquivo que o Semaphore aponta para iniciar uma tarefa automatizada.

---

## 2. Definição dos Inventários

A primeira e mais importante configuração é a definição dos inventários, pois é neles que o Ansible busca o endereço de cada alvo para estabelecer a conexão SSH.

### 2.1. Inventário do Cluster Proxmox

O nosso primeiro alvo é o servidor hipervisor. Para isso, criamos o arquivo `semaphore/invs/proxmox/hosts`:

```ini
[proxmox]
pve ansible_host=10.7.0.47 equipamento="cluster"
```

- **`[proxmox]`** — Nome do grupo. É este nome que as playbooks referenciam no campo `hosts:`.
- **`pve`** — Apelido (alias) amigável para o servidor, em vez de usar o IP diretamente.
- **`ansible_host=10.7.0.47`** — O endereço IP real onde o Ansible irá conectar via SSH.
- **`equipamento="cluster"`** — Variável personalizada que carregamos para identificar o tipo de equipamento nos relatórios e logs.

![Inventário do Proxmox no repositório](../../imagens/semaphore/semaphore-invs-proxmox.png)

### 2.2. Inventário dos Contêineres LXC (Alunos)

Igualmente, criamos o inventário para os contêineres dos alunos que foram provisionados pelo Terraform na fase anterior. O arquivo está em `semaphore/invs/lxc/hosts`:

```ini
[alunos]
aluno-01 ansible_host=[IP_ADDRESS]
aluno-02 ansible_host=[IP_ADDRESS]

[alunos:vars]
local="LAB REDES"
equipamento="LXC"
```

- **`[alunos]`** — Grupo contendo todos os contêineres de alunos.
- **`aluno-01` / `aluno-02`** — Nomes amigáveis que correspondem exatamente aos hostnames gerados pelo Terraform (`format("aluno-%02d", i + 1)`).
- **`[alunos:vars]`** — Bloco especial que define variáveis aplicadas automaticamente a **todos** os membros do grupo, evitando repetição. Todo aluno herda `local="LAB REDES"` e `equipamento="LXC"`.

---

## 3. Primeira Tarefa: Ping no Proxmox

Com os inventários definidos, podemos criar a nossa primeira tarefa de validação: verificar se o Ansible consegue se comunicar com o cluster Proxmox.

### 3.1. A Playbook (`ping-proxmox.yml`)

```yaml
- hosts: proxmox
  roles:
  - ping-proxmox
```

Este arquivo é intencionalmente simples e direto:
- **`hosts: proxmox`** — Informa ao Ansible para buscar no inventário o grupo chamado `proxmox` e executar as instruções em todos os membros desse grupo.
- **`roles: - ping-proxmox`** — Delega a execução para a role `ping-proxmox`, que contém as tarefas reais a serem executadas.

### 3.2. A Role (`roles/ping-proxmox/tasks/main.yml`)

```yaml
- name: Ping proxmox
  ansible.builtin.ping:
  register: status_out

- name: Equipamento
  debug:
    msg: "{{ equipamento }} {{ local }}"

- name: Relatorio
  debug:
    var: status_out
```

Detalhamento de cada tarefa:

1. **`Ping proxmox`** — Utiliza o módulo nativo `ansible.builtin.ping` para testar a comunicação SSH com o host alvo. O resultado é armazenado na variável `status_out` pelo comando `register`.

2. **`Equipamento`** — Exibe no log as variáveis `equipamento` e `local` que foram definidas no inventário. Isso confirma que o Ansible está lendo corretamente os metadados associados a cada host.

3. **`Relatorio`** — Imprime o conteúdo completo da variável `status_out`, permitindo verificar no log se o ping retornou `"pong"` (sucesso) ou uma mensagem de erro.

### 3.3. Resultado da Execução no Semaphore

Ao executar esta tarefa pela interface do Semaphore, podemos acompanhar o resultado em tempo real:

![Resultado da tarefa de ping no Proxmox executada pelo Semaphore](../../imagens/semaphore/semaphore-task-proxmox-ping.png)

---

## 4. Configuração do Repositório Ansible no Semaphore

Os mesmos passos demonstrados anteriormente para o repositório do Terraform são repetidos agora para o repositório Ansible. A grande vantagem é que a chave de API do GitHub já está configurada no Semaphore desde a Fase 3, então o acesso ao novo repositório privado é imediato.

O procedimento consiste em:
1. Publicar todo o conteúdo da pasta `semaphore/` em um repositório privado no GitHub (via `git add`, `commit` e `push`).
2. Acessar a interface do Semaphore e adicionar o novo repositório na seção de **Repositories**.

![Repositório do Ansible configurado com sucesso no Semaphore](../../imagens/semaphore/semaphore-github-created.png)

Com o repositório vinculado, qualquer nova playbook ou role adicionada ao código será automaticamente acessível pelo Semaphore na próxima execução, bastando um simples `git push` para atualizar.
