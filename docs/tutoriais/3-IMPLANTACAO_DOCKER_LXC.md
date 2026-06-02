# Implantação e Configuração de Contêiner LXC para Docker

Para hospedar as aplicações e serviços empacotados que complementarão o laboratório do IFRO, tornou-se necessária a criação de um contêiner Linux (LXC) isolado para a execução da *engine* do Docker e do Docker Compose.

Este documento documenta os passos e parametrizações necessários para construir e adaptar o contêiner dentro do Proxmox para suportar o aninhamento de contêineres Docker (*Docker in LXC*).

---

## 1. Especificações Iniciais do Contêiner

O LXC base foi provisionado no nó primário do cluster utilizando especificações arrojadas para aguentar as cargas dos serviços do Docker. As características de *hardware* e segurança foram parametrizadas conforme a listagem abaixo:

* **Node Operante:** `pve` (O *host* Proxmox).
* **Tipo de Contêiner:** `Unprivileged: Yes` (*Recomendado para isolação e segurança*).
* **Processamento (vCPU):** 5 CPU(s)
* **Memória RAM Instalada:** 7.81 GiB (Dedicada ao Docker e suas pilhas).
* **Armazenamento de Boot (Disk):** 50.00 GiB (Armazenamento suficiente para camadas e volumes *Docker/containers*).

O painel de monitoramento a seguir confirma o sucesso do instanciamento com consumos nulos na etapa pós-instalação base:

![Informações de Criação do LXC Docker](../../imagens/docker/lxc.png)

---

## 2. Ajustes de Segurança de Perfil (Features e AppArmor)

Embora recomendável por boas práticas criar o LXC como desprivilegiado (*Unprivileged*), para rodar o Docker internamente de forma transparente é obrigatório afrouxar cirurgicamente certas diretrizes nativas do Kernel Proxmox base, reescrevendo o arquivo de configuração do contêiner (`101.conf` ou equivalente ao ID).

No terminal raiz (ou via acesso SSH) direcionado ao próprio nó hospedeiro do Proxmox (`root@proxmox`), editamos as configurações fisiológicas do contêiner recém-criado:

```bash
root@proxmox:~# nano /etc/pve/lxc/101.conf
```

Para destrancar o carregamento de Cgroups e anular as travas do AppArmor para esta máquina específica, adicionamos as três linhas abaixo explicitamente no final de seu arquivo correspondente:

```text
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
```

### 2.1 Justificativa das Alterações aplicadas no Host

* `lxc.apparmor.profile: unconfined`: Transborda o isolamento nativo de proteção do AppArmor no lado do *Host* que, caso permanecesse ativo, interceptaria negativamente e bloquearia a alocação técnica de rede (*bridges* do docker) e a montagem das camadas OverlayFS.
* `lxc.cgroup2.devices.allow: a` e `lxc.cap.drop:`: Promovem a correta delegação (*passthrough*) e relaxamento dos subsistemas restritivos do *Control Groups V2*, sendo estritamente exigidos pelas versões modernas da Docker Engine. Permitem criação e acesso irrestrito aos dispositivos aninhados (*nesting* de contêiner virtual) suspendendo a derrubada de *capabilities* (trava de comandos Kernel) limitadoras originais do LXC.

> Após salvar o arquivo na camada Proxmox, faz-se estritamente necessário **reiniciar o LXC** originário (via interface gráfica PVE ou via console do próprio host `pct restart 101`) para que a aplicação force a releitura enxergando estes parâmetros relaxados durante o *boot* atualizado.

---

## 3. Instalação e Configuração do Docker

Após as liberações de isolamento e o reinício do LXC, acessamos o terminal diretamente por dentro do próprio contêiner (`root@docker`) e preparamos um script automatizado de instalação. Este método foca em garantir que os manipuladores certificados do `docker-ce` e `docker-compose-plugin` sejam carregados estritamente da ponte oficial da fabricante (Hashicorp/DockerHQ).

Navegue até um diretório conveniente (ex: `~/scripits`) e inicialize a construção do arquivo:

```bash
root@docker:~/scripits# nano docker-install.sh
```

Preencha o documento com os blocos de *pulling* e validação de chaves criptográficas (GPG) abaixo. Note que o script injeta a string do repositório homologado baseando-se na versão do SO de fundo (com *fallback* estrutural para o `bookworm`):

```bash
# Instala dependências de rede e certificados
apt update && apt install -y curl gnupg ca-certificates

# Adiciona a chave oficial do Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Configura o repositório (Usando codinome bookworm se o trixie ainda não estiver mapeado nativamente)
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs 2>/dev/null || echo bookworm) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instala o Docker CE e o Plugin do Compose
apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

Torne-o executável e comande a rodada de instalações das bibliotecas listadas:

```bash
root@docker:~/scripits# chmod +x docker-install.sh 
root@docker:~/scripits# ./docker-install.sh
```

### 3.1 Verificação do Agente Docker

Após a compilação paralela finalizada pelo `apt`, você pode investigar imediatamente o status do pacote gerado invocando o binário pela linha de comando global:

```bash
root@docker:~/scripits# docker -v 
Docker version 29.3.0, build 5927d80
```

Com essa devolução, é provado que o cliente (Nesse exemplo a compilação `29.3.0`) está responsivo. Esta infraestrutura agora encontra-se capaz de alocar em seu interior (em níveis de containers e redes criadas) a hospedagem dos nós dependentes do laboratório, unindo base para as automações tanto da camada Semaphore, quanto do consumo ativo do Terraform!

---

## 4. Gerenciamento Visual com Komodo

Visando descomplicar a implantação, depuração técnica e a visualização dos contêineres orquestrados de forma transparente, optamos por instalar uma interface gráfica Administrativa dentro do próprio *Host* do Docker. Para este projeto utilizaremos o **Komodo** (modelo MongoDB).

### 4.1 Por que Komodo em vez de Portainer?

Embora o *Portainer* seja uma opção veterana padrão para gerência de instâncias, no contexto de automação de laboratórios atuar com o *Komodo* oferece agilidade superior baseada nos seguintes pontos estruturais:

* **Orientado a Infraestrutura (*Control Plane* Geral):** O Komodo transpõe o pilar puramente do Docker e incorpora nativamente a gerência global da máquina hospedeira. Ele agrega *scripts* e monitoramentos sistêmicos na mesma tela sem plugins arbitrários, comportando-se efetivamente como um painel de controle híbrido.
* **Design Enxuto e Funcional:** Possui uma interface gráfica imensamente descarregada, moderna e amigável. Ações corriqueiras demandadas na elaboração do TCC (entrar em um shell específico de container, puxar logs ao vivo temporários, recarregar sub-redes) demandam menos guias e cliques de navegação.
* **Motor Isolado (Via MongoDB):** O bloco de configuração em questão aloca os bancos vitais de configuração e *reports* de compilação em um ambiente paralelo da stack (através do serviço *MongoDB* nativo). Isso garante recuperação elástica das políticas da máquina do *Host* e agiliza subidas escalonadas caso haja imprevistos lógicos no servidor de alunos.

### 4.2 Execução do Deployment via Docker Compose

O provisionamento foi parametrizado pelos manifestos copiados ou alimentados para a máquina de trabalho na pasta fixa designada do laboratório: `/opt/komodo`.

*(Nota de organização de repositório: Estes manifestos estão espelhados localmente na trilha original `composer/komodo/mongo.compose.yaml`).*

No terminal referenciado do *Host* Docker, validamos então a estrutura existente dos dois artefatos base:

```bash
root@docker:~# cd /opt/komodo
root@docker:/opt/komodo# ls
compose.env  mongo.compose.yaml
```

Reconhecidos os arquivos de declaração, iniciamos o *daemon* do compose passando implicitamente a variável de ambiente do projeto (indicando as flags `--env-file` e `-f` para pular o nome *docker-compose.yaml* restrito) e determinando a subida destacada do plano (`-d`):

```bash
root@docker:/opt/komodo# docker compose -p komodo -f mongo.compose.yaml --env-file compose.env up -d
```

### 4.3 Verificando a Compilação Final

A subida disparará os empacotamentos sequenciais extraindo o agente do Banco (`mongo`), o núcleo mestre do Komodo (`komodo-core`) e seu escravo local (`komodo-periphery`), entregando o status operacional conforme o *log* terminal de construção:

```text
[+] up 43/43
 ✔ Image ghcr.io/moghtech/komodo-core:latest      Pulled                                                                                                             32.5s
 ✔ Image mongo                                    Pulled                                                                                                             24.7s
 ✔ Image ghcr.io/moghtech/komodo-periphery:latest Pulled                                                                                                             30.9s
 ✔ Network komodo_default                         Created                                                                                                            0.0s
 ✔ Volume komodo_mongo-data                       Created                                                                                                            0.0s
 ✔ Volume komodo_mongo-config                     Created                                                                                                            0.0s
 ✔ Container komodo-mongo-1                       Started                                                                                                            0.8s
 ✔ Container komodo-periphery-1                   Started                                                                                                            0.7s
 ✔ Container komodo-core-1                        Started
```

Com todas as áreas vitais inicializadas e as imagens baixadas do registro matriz, o subsistema do Komodo assumirá o monitoramento do servidor em pano de fundo (*Background*). A UI final fica disponível instantaneamente escutando pelo protocolo HTTP global da LXC voltado para a porta designada de aplicação local (Geralmente no endereço `http://[IP-DO-DOCKER]:9120`).

![Login do Komodo](../../imagens/docker/komodo-login.png)

![Dashboard do Komodo](../../imagens/docker/komodo-dashboard.png)
